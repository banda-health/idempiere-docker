#!/usr/bin/env bash

# This script alternates between installing SQL scripts & 2-packs to ensure a true sequence of installation
# Since 2-packs typically run after SQL scripts in our installation, this script sorts all SQL scripts &
# 2-packs by their names, then tries to run as many SQL scripts & 2-packs as possible
# For example, if you had the following:
#   2020-01-01_script.sql
#   2021-01-01_2-pack.zip
#   2021-01-02_2-pack.zip
#   2022-01-01_script.sql
#   2022-01-02_script.sql
#   2022-01-03_script.zip
# This script will run:
#   DB sync:            2020-01-01_script.sql
#   Apply 2-packs:      2021-01-01_2-pack.zip, 2021-01-02_2-pack.zip
#   DB sync:            2022-01-01_script.sql, 2022-01-02_script.sql
#   Apply 2-packs:      2022-01-03_script.zip

# If no directory was provided
if [[ -z "$1" ]]; then
  echo "Please provide a location to readh the migration files from"
  exit 1
fi

migrate() {
  echo "Running incremental migration..."
  "$IDEMPIERE_HOME/utils/RUN_SyncDB.sh" || exit 1

  "$IDEMPIERE_HOME/utils/RUN_ApplyPackInFromFolder.sh" "$IDEMPIERE_HOME/migration"

  # if there were any errors in the DB sync or pack-in migration, we need to throw an error here
  if grep -qr "Failed application of" "$IDEMPIERE_HOME/log"; then
      echo "Failed applying 2-packs, so exiting..."
      exit 1
  fi
}

# If there are no files, then exit
if [[ ! -d "$1" ]]; then
  echo "No migration files in specified directory $1, so exiting..."
  exit
fi

mkdir -p "$IDEMPIERE_HOME/migration/local_sql/postgresql"
mkdir -p "$IDEMPIERE_HOME/migration/zip_2pack"

# Put the files in a single, temporary location
temp_migration_folder=/tmp/bh-migration
rm -rf "$temp_migration_folder"
mkdir "$temp_migration_folder"
find "$1" -type f \( -name "*.sql" -o -name "*.zip" \) -not -path "*/processes_*" -exec cp "{}" "$temp_migration_folder" \;

# Sort the SQL & 2-packs by date
migration_order_file=/tmp/bh-migration-sequence
rm -f "$migration_order_file"
touch "$migration_order_file"
ls "$temp_migration_folder" | sort >"$migration_order_file"

# To avoid a long-running terminology syncing, we'll remove it from intermediate migrations
mv "$IDEMPIERE_HOME/migration/processes_post_migration/postgresql/02_SynchronizeTerminology.sql" "$IDEMPIERE_HOME/migration/processes_post_migration/postgresql/02_SynchronizeTerminology.txt" 2>/dev/null

# Perform a loop to incrementally move things to the migration folder and run them
current_migration_file=/tmp/bh-current-migration-sequence.txt
rm -f "$current_migration_file"
touch "$current_migration_file"
ready_to_migrate=false
was_last_line_zip=false
migration_count=1
while IFS= read -r line; do
  # If the last line was a zip and this line is a SQL, we're ready to migrate!
  if [ "$was_last_line_zip" = true ] && grep -q -i ".sql" <<<"$line"; then
    ready_to_migrate=true
  fi
  # MIGRATE!
  if [ "$ready_to_migrate" = true ]; then
    # Move SQL files to migration local SQL folder
    cat "$current_migration_file" | grep -i ".sql" | xargs -i cp "$temp_migration_folder/{}" "$IDEMPIERE_HOME/migration/local_sql/postgresql"
    # Move ZIP files
    cat "$current_migration_file" | grep -i ".zip" | xargs -i cp "$temp_migration_folder/{}" "$IDEMPIERE_HOME/migration/zip_2pack"
    echo "Migrating count: $migration_count"
    ((migration_count = migration_count + 1))
    migrate || exit 1
    ready_to_migrate=false
    rm -f "$current_migration_file"
    touch "$current_migration_file"
  fi
  echo "$line" >>"$current_migration_file"
  # If this line is a zip, set our variable
  grep -q -i ".zip" <<<"$line" && was_last_line_zip=true || was_last_line_zip=false
done <"$migration_order_file"

# Undo the terminology syncing file rename
mv "$IDEMPIERE_HOME/migration/processes_post_migration/postgresql/02_SynchronizeTerminology.txt" "$IDEMPIERE_HOME/migration/processes_post_migration/postgresql/02_SynchronizeTerminology.sql" 2>/dev/null

# Now move everything to the migration folder and run everything one last time
echo "Copying over Banda migration files..."
cp -r "$1/." "$IDEMPIERE_HOME/migration"

echo "Running final migration, number $migration_count..."
migrate || exit 1

rm -f "$migration_order_file"
rm -rf "$temp_migration_folder"
rm -f "$current_migration_file"
echo "Incremental migration completed!"
