export $(grep -v '^#' .env | xargs)
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h localhost -p $POSTGRES_PORT -U postgres -Fc $DB_NAME > idempiere-db.dmp