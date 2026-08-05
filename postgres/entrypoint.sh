#!/bin/bash
set -e

# Prepare data directory
mkdir -p /var/lib/postgresql/data/pgdata
chown -R postgres:postgres /var/lib/postgresql /var/lib/postgresql/data 2>/dev/null
rm -f /var/lib/postgresql/data/pgdata/postmaster.pid 2>/dev/null

export PGDATA=/var/lib/postgresql/data/pgdata

# Ensure Postgres listens on all interfaces so Railway private networking can reach it.
# Allow connections from the Railway private network (10.0.0.0/8) using md5 auth.
cat >> /etc/postgresql/pg_hba.conf <<'HBA'
host  all  all  10.0.0.0/8  md5
host  all  all  127.0.0.1/32  trust
host  all  all  ::1/128  trust
HBA

# Start postgres in background, forcing listen on all interfaces.
docker-entrypoint.sh postgres \
  -c config_file=/etc/postgresql/postgresql.conf \
  -c data_directory=/var/lib/postgresql/data/pgdata \
  -c listen_addresses='*' &
PG_PID=$!

# Wait for postgres to be ready
wait_for_ready() {
  for i in $(seq 1 60); do
    if su postgres -c "pg_isready -h 127.0.0.1 -p 5432" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

echo "Waiting for postgres to start..."
if ! wait_for_ready; then
  echo "Postgres did not become ready in time." >&2
  kill $PG_PID 2>/dev/null || true
  wait $PG_PID 2>/dev/null || true
  exit 1
fi
echo "Postgres is ready."

# Grant permissions on all supabase schemas to postgres user.
# Connect as postgres (default superuser in the supabase/postgres image)
# and ensure it has SUPERUSER plus the _realtime schema exists.
echo "Granting schema permissions and creating roles..."
su postgres -c "psql -h 127.0.0.1 -U postgres -d postgres" <<'SQL' || true
-- Make postgres a SUPERUSER so it can run migrations on all schemas
ALTER ROLE postgres WITH SUPERUSER;
-- Ensure schemas exist for supabase service migrations
CREATE SCHEMA IF NOT EXISTS auth;
GRANT ALL ON SCHEMA auth TO postgres;
CREATE SCHEMA IF NOT EXISTS storage;
GRANT ALL ON SCHEMA storage TO postgres;
CREATE SCHEMA IF NOT EXISTS _realtime;
GRANT ALL ON SCHEMA _realtime TO postgres;
-- Create Supabase roles required by storage-api migrations
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END
$$;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
SQL
echo "Schema permissions and roles created."

# Wait for the background postgres process
wait $PG_PID
