#!/bin/bash
set -e

echo "=============================================="
echo " TDS_FDW JOIN Pushdown Test Initialization"
echo "=============================================="

# Wait for PostgreSQL to be ready
until pg_isready -U postgres; do
  echo "Waiting for PostgreSQL..."
  sleep 1
done

echo "PostgreSQL is ready. Configuring tds_fdw extension..."

# Create extension and foreign server
psql -U postgres -d testdb <<EOF
-- Create the extension
CREATE EXTENSION IF NOT EXISTS tds_fdw;

-- Create foreign server (adjust connection details as needed)
CREATE SERVER IF NOT EXISTS sybase_server
  FOREIGN DATA WRAPPER tds_fdw
  OPTIONS (
    servername '${SYBASE_HOST:-host.docker.internal}',
    port '${SYBASE_PORT:-5000}',
    database '${SYBASE_DATABASE:-master}',
    tds_version '5.0',
    msg_handler 'notice'
  );

-- Create user mapping
CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER sybase_server
  OPTIONS (
    username '${SYBASE_USER:-sa}',
    password '${SYBASE_PASSWORD:-myPassword}'
  );

-- Import foreign schemas
IMPORT FOREIGN SCHEMA bethadba 
  LIMIT TO (foempregados) 
  FROM SERVER sybase_server 
  INTO public;

IMPORT FOREIGN SCHEMA bethadba 
  LIMIT TO (focargos) 
  FROM SERVER sybase_server 
  INTO public;

-- Grant permissions
DO \$\$
BEGIN
  EXECUTE 'GRANT SELECT ON foempregados TO postgres';
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table foempregados does not exist yet';
END \$\$;

DO \$\$
BEGIN
  EXECUTE 'GRANT SELECT ON focargos TO postgres';
EXCEPTION WHEN undefined_table THEN
  RAISE NOTICE 'Table focargos does not exist yet';
END \$\$;
EOF

echo "=============================================="
echo " Foreign tables configured successfully!"
echo "=============================================="

