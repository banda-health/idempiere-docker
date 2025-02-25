#!/usr/bin/env bash

set -Eeo pipefail

cd $IDEMPIERE_HOME

# this must be created first so the health check knows what the status is
touch ./.unhealthy

# Link the idempiere command to the server script
if [[ ! -f "/usr/bin/idempiere" ]]; then
    ln -s $IDEMPIERE_HOME/idempiere-server.sh /usr/bin/idempiere > /dev/null 2>&1
fi

KEY_STORE_PASS=${KEY_STORE_PASS:-bandaHealth}
KEY_STORE_ON=${KEY_STORE_ON:-bandahealth.org}
KEY_STORE_OU=${KEY_STORE_OU:-Banda iDempiere Docker}
KEY_STORE_O=${KEY_STORE_O:-iDempiere}
KEY_STORE_L=${KEY_STORE_L:-Colorado Springs}
KEY_STORE_S=${KEY_STORE_S:-CO}
KEY_STORE_C=${KEY_STORE_C:-US}
IDEMPIERE_HOST=${IDEMPIERE_HOST:-0.0.0.0}
IDEMPIERE_PORT=${IDEMPIERE_PORT:-8080}
IDEMPIERE_SSL_PORT=${IDEMPIERE_SSL_PORT:-8443}
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-idempiere}
DB_USER=${DB_USER:-adempiere}
DB_PASS=${DB_PASS:-adempiere}
DB_ADMIN_PASS=${DB_ADMIN_PASS:-postgres}
MAIL_HOST=${MAIL_HOST:-0.0.0.0}
MAIL_USER=${MAIL_USER:-info}
MAIL_PASS=${MAIL_PASS:-info}
MAIL_ADMIN=${MAIL_ADMIN:-info@idempiere}
MIGRATE_EXISTING_DATABASE=${MIGRATE_EXISTING_DATABASE:-false}
IDEMPIERE_FRESH_DB=${IDEMPIERE_FRESH_DB:-false}
REMOVE_SOURCES_AFTER_COPY=${REMOVE_SOURCES_AFTER_COPY:-false}
INSTALLATION_HOME=${INSTALLATION_HOME:-/home/src}

if [[ -n "$DB_PASS_FILE" ]]; then
    echo "DB_PASS_FILE set as $DB_PASS_FILE..."
    DB_PASS=$(cat $DB_PASS_FILE)
fi

if [[ -n "$DB_ADMIN_PASS_FILE" ]]; then
    echo "DB_ADMIN_PASS_FILE set as $DB_ADMIN_PASS_FILE..."
    DB_ADMIN_PASS=$(cat $DB_ADMIN_PASS_FILE)
fi

if [[ -n "$MAIL_PASS_FILE" ]]; then
    echo "MAIL_PASS_FILE set as $MAIL_PASS_FILE..."
    MAIL_PASS=$(cat $MAIL_PASS_FILE)
fi

if [[ -n "$KEY_STORE_PASS_FILE" ]]; then
    echo "KEY_STORE_PASS_FILE set as $KEY_STORE_PASS_FILE..."
    KEY_STORE_PASS=$(cat $KEY_STORE_PASS_FILE)
fi

if [[ "$1" == "idempiere" ]]; then
    RETRIES=30

    until PGPASSWORD=$DB_ADMIN_PASS psql -h $DB_HOST -p $DB_PORT -U postgres -c "\q" >/dev/null 2>&1 || [[ $RETRIES == 0 ]]; do
        echo "Waiting for postgres server, $((RETRIES--)) remaining attempts..."
        sleep 1
    done

    if [[ $RETRIES == 0 ]]; then
        echo "Shutting down..."
        exit 1
    fi

    echo "Removing default settings..."
    rm -f idempiereEnv.properties jettyhome/etc/keystore

    echo "Adding DB role if it doesn't exist..."
    if ! PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "\q" >/dev/null 2>&1; then
        PGPASSWORD=$DB_ADMIN_PASS psql -h $DB_HOST -p $DB_PORT -U postgres -c "CREATE ROLE adempiere SUPERUSER LOGIN PASSWORD '$DB_PASS';" >/dev/null 2>&1
    fi

    echo "Executing console-setup..."
    echo -e "$JAVA_HOME\n$IDEMPIERE_HOME\n$KEY_STORE_PASS\n$KEY_STORE_ON\n$KEY_STORE_OU\n$KEY_STORE_O\n$KEY_STORE_L\n$KEY_STORE_S\n$KEY_STORE_C\n$IDEMPIERE_HOST\n$IDEMPIERE_PORT\n$IDEMPIERE_SSL_PORT\nN\n2\n$DB_HOST\n$DB_PORT\n$DB_NAME\n$DB_USER\n$DB_PASS\n$DB_ADMIN_PASS\n$MAIL_HOST\n$MAIL_USER\n$MAIL_PASS\n$MAIL_ADMIN\nY\n" | ./console-setup.sh

    # If no DB exists or we want a fresh one, do it
    echo "Checking if a new DB is needed..."
    willUseNewDb=0
    # If we don't want to use a new DB and one exists, we'll not recreate the DB
    if [ $IDEMPIERE_FRESH_DB != "true" ]; then
        if PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "\q" >/dev/null 2>&1; then
            willUseNewDb=1
        fi
    fi
    wasBaseIdempiereDBUsed=1
    if ((willUseNewDb == 0)); then
        # Delete the DB, if it's there
        if PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "\q" >/dev/null 2>&1; then
            echo "Database '$DB_NAME' is found. Dropping it so there is a fresh instance..."
            PGPASSWORD=$DB_ADMIN_PASS psql -h $DB_HOST -p $DB_PORT -U postgres -c "drop database \"${DB_NAME}\";"
        fi

        cd utils
        # If a DB file was provided, we'll use that
        if [[ -f "$INSTALLATION_HOME/initial-db.dmp" ]]; then
            echo "Adding new DB..."
            PGPASSWORD=$DB_ADMIN_PASS psql -h $DB_HOST -p $DB_PORT -U postgres -c "create database ${DB_NAME} owner adempiere;" >/dev/null 2>&1
            echo "Importing DB initialization file to database '$DB_NAME' with pg_restore version $(pg_restore --version)..."
            PGPASSWORD=$DB_ADMIN_PASS pg_restore -h $DB_HOST -p $DB_PORT -U postgres -Fc -j 8 -d $DB_NAME "$INSTALLATION_HOME/initial-db.dmp"
            PGPASSWORD=$DB_ADMIN_PASS psql -h $DB_HOST -p $DB_PORT -U postgres -c "ALTER ROLE adempiere SET search_path TO adempiere, pg_catalog;" >/dev/null 2>&1
        else
            wasBaseIdempiereDBUsed=0
            echo "Importing new database '$DB_NAME'..."
            ./RUN_ImportIdempiere.sh
        fi
        echo "Synchronizing database..."
        ./RUN_SyncDB.sh
        cd ..
    else
        echo "Did not create a new DB"
    fi
    if ((wasBaseIdempiereDBUsed == 0)) || [[ $MIGRATE_EXISTING_DATABASE == "true" ]]; then
        if [[ -d "$INSTALLATION_HOME/migration" ]]; then
            echo "Incrementally syncing files..."
            /install-migrations-incrementally.sh "$INSTALLATION_HOME/migration" || exit 1
            if [[ $REMOVE_SOURCES_AFTER_COPY == "true" ]]; then
                echo "Removing source migrations after copy..."
                rm -rf $INSTALLATION_HOME/migration/*
            fi
        fi

        cd utils
        echo "Synchronizing database..."
        ./RUN_SyncDB.sh
        cd ..
        echo "Signing database..."
        ./sign-database-build.sh
    else
        echo "Will use existing DB as-is..."
    fi

    if [[ "$2" == "install-sources" ]]; then
        /install-sources.sh
    fi
fi

# remove the unhealthy file so Docker health check knows everything succeeded
rm ./.unhealthy

exec "$@"
