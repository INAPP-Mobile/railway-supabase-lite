#!/bin/bash
set -e
# Render Kong declarative config from env at runtime.
# Uses Railway private domains (best practice) for inter-service traffic.

export SUPABASE_AUTH_HOST=${AUTH_HOST}
export SUPABASE_REST_HOST=${REST_HOST}
export SUPABASE_REALTIME_HOST=${REALTIME_HOST}
export SUPABASE_STORAGE_HOST=${STORAGE_HOST}

cat > /tmp/kong.yml <<EOF
_format_version: "2.1"
services:
  - name: auth
    url: http://${SUPABASE_AUTH_HOST}:9999/verify
    routes:
      - name: auth-route
        paths: ["/auth/v1/verify"]
  - name: auth-admin
    url: http://${SUPABASE_AUTH_HOST}:9999/
    routes:
      - name: auth-admin-route
        paths: ["/auth/v1/"]
  - name: rest
    url: http://${SUPABASE_REST_HOST}:3000/
    routes:
      - name: rest-route
        paths: ["/rest/v1/"]
  - name: realtime
    url: http://${SUPABASE_REALTIME_HOST}:4000/socket/
    routes:
      - name: realtime-route
        paths: ["/realtime/v1/"]
  - name: storage
    url: http://${SUPABASE_STORAGE_HOST}:5000/
    routes:
      - name: storage-route
        paths: ["/storage/v1/"]
plugins:
  - name: cors
    config:
      origins: ["*"]
      methods: ["GET","POST","PUT","PATCH","DELETE","OPTIONS"]
      headers: ["Authorization","apikey","Content-Type"]
      credentials: true
EOF

export KONG_DATABASE=off
export KONG_DECLARATIVE_CONFIG=/tmp/kong.yml
export KONG_PROXY_LISTEN="0.0.0.0:8000"
export KONG_ADMIN_LISTEN="0.0.0.0:8001"

exec /docker-entrypoint.sh kong docker-start
