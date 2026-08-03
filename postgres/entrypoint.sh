#!/bin/bash
set -e

# Prepare data directory
mkdir -p /var/lib/postgresql/data/pgdata
chown -R postgres:postgres /var/lib/postgresql /var/lib/postgresql/data 2>/dev/null
rm -f /var/lib/postgresql/data/pgdata/postmaster.pid 2>/dev/null

export PGDATA=/var/lib/postgresql/data/pgdata

# Start postgres in background
docker-entrypoint.sh postgres -c config_file=/etc/postgresql/postgresql.conf -c data_directory=/var/lib/postgresql/data/pgdata &
PG_PID=$!

# Wait for postgres to be ready
echo "Waiting for postgres to start..."
for i in $(seq 1 30); do
  if su postgres -c "pg_isready -h 127.0.0.1 -p 5432" 2>/dev/null; then
    echo "Postgres is ready."
    break
  fi
  sleep 1
done

# Grant permissions on all supabase schemas to postgres user.
# Each statement runs in its own transaction with exception handling
# so one failure (e.g. pgbouncer) doesn't roll back the others.
echo "Granting schema permissions..."
# Connect as supabase_admin (the actual superuser in supabase/postgres image)
# to elevate the postgres role and grant schema permissions.
su postgres -c "psql -h 127.0.0.1 -U supabase_admin -d postgres" <<'SQL'
-- Make postgres a SUPERUSER so it can run migrations on all schemas
ALTER ROLE postgres WITH SUPERUSER;
SQL
echo "Schema permissions granted."

# Wait for the background postgres process
wait $PG_PID
