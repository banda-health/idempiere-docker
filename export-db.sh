export $(grep -v '^#' .env | xargs)
DB_HOST_TO_USE=${DB_HOST:-localhost}
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h $DB_HOST_TO_USE -p $POSTGRES_PORT -U postgres -Fc $DB_NAME > idempiere-db.dmp