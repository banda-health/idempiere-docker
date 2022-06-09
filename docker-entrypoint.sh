#!/usr/bin/env bash

set -Eeo pipefail

# this must be created first so the health check knows what the status is
touch ./.unhealthy

# remove all log files
rm -rf log/*
rm -rf /opt/idempiere/*

cp /home/src/idempiere.build.gtk.linux.x86_64.tar.gz /tmp

tar -zxf /tmp/idempiere.build.gtk.linux.x86_64.tar.gz --directory /tmp && \
    mv /tmp/x86_64/* $IDEMPIERE_HOME && \
    rm -rf /tmp/idempiere* && \
    rm -rf /tmp/x86_64*
ln -s $IDEMPIERE_HOME/idempiere-server.sh /usr/bin/idempiere

KEY_STORE_PASS=${KEY_STORE_PASS:-myPassword}
KEY_STORE_ON=${KEY_STORE_ON:-idempiere.org}
KEY_STORE_OU=${KEY_STORE_OU:-iDempiere Docker}
KEY_STORE_O=${KEY_STORE_O:-iDempiere}
KEY_STORE_L=${KEY_STORE_L:-myTown}
KEY_STORE_S=${KEY_STORE_S:-CA}
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
MIGRATE_EXISTING_DATABASE=${MIGRATE_EXISTING_DATABASE:false}
IDEMPIERE_FRESH_DB=${IDEMPIERE_FRESH_DB:false}
EXPORT_DB=${EXPORT_DB:false}

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

    until PGPASSWORD=$DB_ADMIN_PASS psql -h $DB_HOST -U postgres -c "\q" > /dev/null 2>&1 || [[ $RETRIES == 0 ]]; do
        echo "Waiting for postgres server, $((RETRIES--)) remaining attempts..."
        sleep 1
    done

    if [[ $RETRIES == 0 ]]; then
        echo "Shutting down..."
        exit 1
    fi

    echo "Removing default settings..."
    rm -f idempiereEnv.properties jettyhome/etc/keystore

    echo "Executing console-setup..."
    echo -e "$JAVA_HOME\n$IDEMPIERE_HOME\n$KEY_STORE_PASS\n$KEY_STORE_ON\n$KEY_STORE_OU\n$KEY_STORE_O\n$KEY_STORE_L\n$KEY_STORE_S\n$KEY_STORE_C\n$IDEMPIERE_HOST\n$IDEMPIERE_PORT\n$IDEMPIERE_SSL_PORT\nN\n2\n$DB_HOST\n$DB_PORT\n$DB_NAME\n$DB_USER\n$DB_PASS\n$DB_ADMIN_PASS\n$MAIL_HOST\n$MAIL_USER\n$MAIL_PASS\n$MAIL_ADMIN\nY\n" | ./console-setup.sh

    # If no DB exists or we want a fresh one, do it
    [ $IDEMPIERE_FRESH_DB == "true" ]
    willUseNewDb=$?
    if ! PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\q" > /dev/null 2>&1; then
        willUseNewDb=0
    fi
    wasBaseIdempiereDBUsed=1
    if (( willUseNewDb == 0 )); then
        # Delete the DB, if it's there
        if PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\q" > /dev/null 2>&1 ; then
            echo "Database '$DB_NAME' is found. Dropping it so there is a fresh instance..."
            PGPASSWORD=$DB_ADMIN_PASS psql -h $DB_HOST -U postgres -c "drop database ${DB_NAME};"
        fi

        cd utils
        # If a DB file was provided, we'll use that
        if [[ -f "/home/src/initial-db.dmp" ]]; then
            PGPASSWORD=$DB_ADMIN_PASS psql -h "$DB_HOST" -U postgres -c "CREATE ROLE adempiere login password '$DB_PASS';" 2>&1 > /dev/null
            PGPASSWORD=$DB_ADMIN_PASS psql -h "$DB_HOST" -U postgres -c "create database ${DB_NAME} owner adempiere;"
            echo "Importing DB initialization file to database '$DB_NAME'..."
            PGPASSWORD=$DB_ADMIN_PASS pg_restore -h $DB_HOST -U postgres -Fc -j 8 -d $DB_NAME /home/src/initial-db.dmp
            PGPASSWORD=$DB_ADMIN_PASS psql -h "$DB_HOST" -U postgres -c "ALTER ROLE adempiere SET search_path TO adempiere, pg_catalog;" 2>&1 > /dev/null
        else
            wasBaseIdempiereDBUsed=0
            echo "Importing new database '$DB_NAME'..."
            ./RUN_ImportIdempiere.sh
        fi
        echo "Synchronizing database..."
        ./RUN_SyncDB.sh
        cd ..
    fi
    if (( wasBaseIdempiereDBUsed == 0 )) || [[ $MIGRATE_EXISTING_DATABASE == "true" ]]; then
        if [ -d "/home/src/migration" ]; then
            echo "Copying over Banda migration files..."
            cp -r /home/src/migration/. migration
        fi

        cd utils
        echo "Synchronizing database..."
        ./RUN_SyncDB.sh
        cd ..
        echo "Signing database..."
        ./sign-database-build.sh
    fi

    # if there were any errors in the DB sync or pack-in migration, we need to throw an error here
    if grep -q "Failed application of migration/" log/*; then
        exit 1
    fi

    # Export the DB to a file to be leveraged by others
    if [[ $EXPORT_DB == "true" ]]; then
        PGPASSWORD=$DB_ADMIN_PASS pg_dump -h $DB_HOST -U postgres -Fc $DB_NAME > /home/src/idempiere-db.dmp
    fi
fi

# Copy the plugins to the plugin directory, if there are any
cp -r /home/src/plugins/* /opt/idempiere/plugins

# Copy any plugin configuration for plugin auto-starts
if [[ -f "/home/src/bundles.info" ]] && [[ -f "/opt/idempiere/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info" ]]; then
    echo "Ensuring bundles installed..."
    cat /home/src/bundles.info >> /opt/idempiere/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info
fi

# remove the unhealthy file so Docker health check knows everything succeeded
rm ./.unhealthy

exec "$@"

# If we're in our CI pipeline, don't stop the container - the pipeline will close it at the right time
if [[ $CI == "true" ]]; then
    sleep infinity
fi
