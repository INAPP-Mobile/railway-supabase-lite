FROM supabase/postgres:15.8.1.085
# Extensions: pgvector, pgsodium, pg_graphql, pg_net, pgjwt (bundled in image)
# Volume mount: /var/lib/postgresql
# PGDATA: /var/lib/postgresql/data/pgdata
#
# Custom entrypoint: grants schema ownership to 'postgres' user on startup
# so GoTriple/Storage/Realtime migrations can run as 'postgres' without
# "permission denied for schema auth" errors.
COPY entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh
EXPOSE 5432
