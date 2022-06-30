#!/bin/sh
export $(grep -v '^#' .env | grep -v '^$' | xargs)

FILE=docker-compose.yml
if ! [ -z $1 ]; then
	FILE=$1
fi

echo "Using compose file $FILE..."

docker compose -f $FILE exec idempiere sh -c "PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h $POSTGRES_HOST -p $POSTGRES_PORT -U postgres -Fc $DB_NAME > idempiere-db.dmp"
docker compose -f $FILE cp idempiere:idempiere-db.dmp idempiere-db.dmp
