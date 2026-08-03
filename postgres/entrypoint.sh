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
su postgres -c "psql -h 127.0.0.1 -U postgres -d postgres" <<'SQL'
-- Grant schema-level privileges (each schema independently)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT nspname FROM pg_namespace
           WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast', 'pgbouncer')
  LOOP
    BEGIN
      EXECUTE format('GRANT ALL ON SCHEMA %I TO postgres', r.nspname);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Skipping GRANT for schema %: %', r.nspname, SQLERRM;
    END;
    BEGIN
      EXECUTE format('ALTER SCHEMA %I OWNER TO postgres', r.nspname);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Skipping ALTER OWNER for schema %: %', r.nspname, SQLERRM;
    END;
    BEGIN
      EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO postgres', r.nspname);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Skipping TABLE GRANT for schema %: %', r.nspname, SQLERRM;
    END;
    BEGIN
      EXECUTE format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA %I TO postgres', r.nspname);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Skipping SEQUENCE GRANT for schema %: %', r.nspname, SQLERRM;
    END;
    BEGIN
      EXECUTE format('GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA %I TO postgres', r.nspname);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Skipping FUNCTION GRANT for schema %: %', r.nspname, SQLERRM;
    END;
  END LOOP;
END $$;

-- Ensure default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL ON SEQUENCES TO postgres;
SQL
echo "Schema permissions granted."

# Wait for the background postgres process
wait $PG_PID
