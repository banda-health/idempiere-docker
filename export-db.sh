#!/bin/sh
export $(grep -v '^#' .env | grep -v '^$' | xargs)

docker compose exec -ti idempiere sh -c "PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h $POSTGRES_HOST -p $POSTGRES_PORT -U postgres -Fc $DB_NAME > idempiere-db.dmp"
docker compose cp idempiere:idempiere-db.dmp idempiere-db.dmp
