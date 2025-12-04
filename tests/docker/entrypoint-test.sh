#!/bin/bash
# =============================================================================
# TDS_FDW Test Container Entrypoint
# =============================================================================
# This script initializes PostgreSQL and runs the JOIN pushdown tests.
# It uses the postgres user for database operations.
# =============================================================================

set -e

# Start PostgreSQL in the background using the official docker-entrypoint
# We run as postgres user
if [ "$(id -u)" = '0' ]; then
    # We're root, need to switch to postgres user for initialization
    
    # Create data directory with correct permissions
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"
    
    # Create results directory
    mkdir -p /tmp/test-results
    chown -R postgres:postgres /tmp/test-results
    
    # Initialize database as postgres user if not already initialized
    if [ ! -s "$PGDATA/PG_VERSION" ]; then
        echo "Initializing PostgreSQL data directory..."
        
        # Create a temporary password file
        PWFILE=$(mktemp)
        echo "$POSTGRES_PASSWORD" > "$PWFILE"
        chown postgres:postgres "$PWFILE"
        
        gosu postgres initdb --username="$POSTGRES_USER" --pwfile="$PWFILE"
        
        rm -f "$PWFILE"
        
        # Configure PostgreSQL for testing
        cat >> "$PGDATA/postgresql.conf" <<EOF
listen_addresses = '*'
log_statement = 'all'
log_min_messages = warning
client_min_messages = notice
EOF
        
        # Configure authentication
        cat > "$PGDATA/pg_hba.conf" <<EOF
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
host    all             all             0.0.0.0/0               md5
EOF
        chown postgres:postgres "$PGDATA/pg_hba.conf"
    fi
    
    # Start PostgreSQL as postgres user
    echo "Starting PostgreSQL..."
    gosu postgres pg_ctl -D "$PGDATA" -w start
    
    # Create test database if it doesn't exist
    gosu postgres psql -U "$POSTGRES_USER" -tc "SELECT 1 FROM pg_database WHERE datname = '$POSTGRES_DB'" | grep -q 1 || \
        gosu postgres psql -U "$POSTGRES_USER" -c "CREATE DATABASE $POSTGRES_DB"
    
    # Run the tests as postgres user
    exec gosu postgres /usr/local/bin/run-join-test.sh
else
    # Already running as postgres user
    
    # Initialize database if not already initialized
    if [ ! -s "$PGDATA/PG_VERSION" ]; then
        echo "Initializing PostgreSQL data directory..."
        
        # Create a temporary password file
        PWFILE=$(mktemp)
        echo "$POSTGRES_PASSWORD" > "$PWFILE"
        
        initdb --username="$POSTGRES_USER" --pwfile="$PWFILE"
        
        rm -f "$PWFILE"
        
        # Configure PostgreSQL for testing
        cat >> "$PGDATA/postgresql.conf" <<EOF
listen_addresses = '*'
log_statement = 'all'
log_min_messages = warning
client_min_messages = notice
EOF
        
        # Configure authentication
        cat > "$PGDATA/pg_hba.conf" <<EOF
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
host    all             all             0.0.0.0/0               md5
EOF
    fi
    
    # Start PostgreSQL
    echo "Starting PostgreSQL..."
    pg_ctl -D "$PGDATA" -w start
    
    # Create test database if it doesn't exist
    psql -U "$POSTGRES_USER" -tc "SELECT 1 FROM pg_database WHERE datname = '$POSTGRES_DB'" | grep -q 1 || \
        psql -U "$POSTGRES_USER" -c "CREATE DATABASE $POSTGRES_DB"
    
    # Run the tests
    exec /usr/local/bin/run-join-test.sh
fi
