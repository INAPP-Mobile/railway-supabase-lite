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
  - name: health
    url: http://127.0.0.1:${PORT:-8000}
    routes:
      - name: health-route
        paths: ["/health"]
        strip_path: false
    plugins:
      - name: request-termination
        config:
          status_code: 200
          message: "OK"
  - name: auth
    url: http://${SUPABASE_AUTH_HOST}:${PORT:-8080}/verify
    routes:
      - name: auth-route
        paths: ["/auth/v1/verify"]
  - name: auth-admin
    url: http://${SUPABASE_AUTH_HOST}:${PORT:-8080}/
    routes:
      - name: auth-admin-route
        paths: ["/auth/v1/"]
  - name: rest
    url: http://${SUPABASE_REST_HOST}:${PORT:-8080}/
    routes:
      - name: rest-route
        paths: ["/rest/v1/"]
  - name: realtime
    url: http://${SUPABASE_REALTIME_HOST}:${PORT:-8080}/socket/
    routes:
      - name: realtime-route
        paths: ["/realtime/v1/"]
  - name: storage
    url: http://${SUPABASE_STORAGE_HOST}:${PORT:-8080}/
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
export KONG_PROXY_LISTEN="0.0.0.0:${PORT:-8000}"
export KONG_ADMIN_LISTEN="0.0.0.0:8001"

exec /docker-entrypoint.sh kong docker-start
