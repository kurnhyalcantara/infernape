#!/bin/bash
set -e

# This script runs automatically when the Postgres container starts for the first time.
# It creates separate databases for each microservice.
#
# Databases are specified via the POSTGRES_DATABASES environment variable
# as a comma-separated list. If not set, defaults are used.

DATABASES="${POSTGRES_DATABASES:-araquanid,koer_cash_management,koer_product,koer_task,koer_tax}"

echo "=== Initializing databases ==="

IFS=',' read -ra DB_ARRAY <<< "$DATABASES"
for db in "${DB_ARRAY[@]}"; do
    db=$(echo "$db" | xargs) # trim whitespace
    echo "Creating database: $db"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        SELECT 'CREATE DATABASE $db'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db')\gexec
        GRANT ALL PRIVILEGES ON DATABASE $db TO $POSTGRES_USER;
EOSQL
    echo "Database '$db' ready."
done

echo "=== All databases initialized ==="
echo "Databases created: ${DATABASES}"
