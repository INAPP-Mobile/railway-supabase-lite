# Supabase Lite (Railway Template)

A minimal, cost-optimized self-hosted Supabase stack for Railway. Unlike the full 12-service Supabase template that needs 4–8 GB RAM, **Supabase Lite runs the 7 core services in ~1.5 GB RAM for roughly $10–15/mo**.

[![Deploy to Railway](https://railway.app/button.svg)](https://railway.com/deploy/IGAyxf)

> **Note:** this is an unpublished draft. The deploy link may change if the template is renamed or regenerated.

## What's included

| Service | Upstream image | Port | Purpose |
|---|---|---|---|
| **postgres** | `supabase/postgres:15.8.1.085` | `5432` | PostgreSQL with pgvector, pgjwt, pg_graphql, etc. |
| **kong** | `kong:3.9.1` | `8000` | API gateway — the only public-facing service |
| **auth** | `supabase/gotrue:v2.186.0` | `9999` | Auth / user management (GoTrue) |
| **rest** | `postgrest/postgrest:v14.8` | `3000` | Auto-generated REST API from Postgres schema |
| **realtime** | `supabase/realtime:v2.76.5` | `4000` | WebSocket realtime subscriptions |
| **storage** | `supabase/storage-api:v1.48.26` | `5000` | S3-compatible object storage API |
| **minio** | `minio/minio:RELEASE.2024-11-07T00-52-20Z` | `9000` / `9001` | S3 backend used by Storage |

**Not included:** Studio UI, imgproxy, postgres-meta, edge-runtime, logflare/analytics, supavisor, vector. If you need the dashboard, use the official full Supabase template.

## Architecture

```
┌─────────┐     ┌─────┐     ┌─────────────────────────────────┐
│  Client │────▶│ Kong│────▶│ auth / rest / realtime / storage│
└─────────┘     └─────┘     └─────────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                             ▼
              ┌──────────┐                ┌──────────┐
              │  postgres  │                │  minio   │
              └──────────┘                └──────────┘
```

All upstream services communicate over Railway private networking (`*.railway.internal`). Only Kong is exposed publicly.

## Deploy

Click the button above or run:

```bash
railway deploy https://railway.com/deploy/IGAyxf
```

Railway will provision:
- A shared environment with the 7 services
- Two persistent volumes: `postgres-data` (mounted at `/var/lib/postgresql`) and `minio-data` (mounted at `/data`)
- Required secrets (`POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, `DASHBOARD_PASSWORD`, `MINIO_ROOT_PASSWORD`)

### User-configurable variables

These are defined in each service's `template-vars.json` and prompted on deploy:

| Variable | Service | Default / generator | Purpose |
|---|---|---|---|
| `POSTGRES_PASSWORD` | postgres | `${{ secret(32) }}` | Master Postgres password used by all services |
| `MINIO_ROOT_PASSWORD` | minio | `${{ secret(32) }}` | MinIO root password used by storage-api |
| `JWT_SECRET` | auth | `${{ secret(64) }}` | HS256 signing key for `ANON_KEY` and `SERVICE_ROLE_KEY` |
| `ANON_KEY` | auth | none (required) | Public client JWT — generate from `JWT_SECRET` |
| `SERVICE_ROLE_KEY` | auth | none (required) | Server-side full-access JWT — generate from `JWT_SECRET` |
| `DASHBOARD_USERNAME` | auth | `supabase` | Admin username placeholder |
| `DASHBOARD_PASSWORD` | auth | `${{ secret(16) }}` | Admin password placeholder |

> All internal wiring variables are auto-linked between services via cross-service references (`${{Service.VAR}}`) in the Raw JSON editor.

### Generating `ANON_KEY` and `SERVICE_ROLE_KEY`

Both keys must be JWTs signed by `JWT_SECRET`. Install the Supabase CLI or use any HS256 signer, then generate:

```bash
# Replace <JWT_SECRET> with the value Railway shows for JWT_SECRET
supabase secrets generate --secret <JWT_SECRET>
```

Or with Node.js / jsonwebtoken:

```js
const jwt = require('jsonwebtoken')
const secret = '<JWT_SECRET>' // from Railway auth service variables
const anon = jwt.sign({ role: 'anon' }, secret, { algorithm: 'HS256' })
const service_role = jwt.sign({ role: 'service_role' }, secret, { algorithm: 'HS256' })
```

Paste `anon` into **ANON_KEY** and `service_role` into **SERVICE_ROLE_KEY** in the deploy form.

## Post-deploy setup

After deployment, your public Supabase URL is the Kong service domain:

```
https://<kong-railway-subdomain>.up.railway.app
```

### Connect with the JS client

```js
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://<your-kong-subdomain>.up.railway.app',
  '<ANON_KEY>'  // from Railway variables
)
```

### Service paths

| Feature | Kong path | Upstream |
|---|---|---|
| Auth | `/auth/v1/` | `auth:9999` |
| REST | `/rest/v1/` | `rest:3000` |
| Realtime | `/realtime/v1/` | `realtime:4000/socket/` |
| Storage | `/storage/v1/` | `storage:5000` |
| Gateway health | `/health` | Kong request-termination plugin |

### Verify the stack

```bash
# 1. Get your Kong public domain from Railway variables
curl -sS "https://<kong-domain>/health" -w "\nHTTP %{http_code}\n"
# expected: HTTP 200

# 2. Check REST API spec
curl -sS "https://<kong-domain>/rest/v1/" -H "apikey: <ANON_KEY>"

# 3. Check auth health
curl -sS "https://<kong-domain>/auth/v1/health" -H "apikey: <ANON_KEY>"

# 4. Check storage status
curl -sS "https://<kong-domain>/storage/v1/status" -H "apikey: <ANON_KEY>"
```

## Repository layout

```
.
├── railway.json                 # Root Railway config (builder type, global restart policy)
├── template-vars.json           # User-facing variables for the deploy UI
├── template-editor-raw.json     # Service-level variable wiring (description/value format)
├── companion-mapping.json       # Maps which shared vars each service needs
├── template-icon.svg            # Railway template icon
├── .env.example                 # Local reference of all environment variables
├── auth/                        # GoTrue auth service
│   ├── Dockerfile
│   └── railway.json
├── kong/                        # API gateway
│   ├── Dockerfile
│   ├── entrypoint.sh            # Renders declarative config from env vars
│   └── railway.json
├── minio/                       # S3 backend
│   ├── Dockerfile
│   └── railway.json
├── postgres/                    # Postgres with extensions
│   ├── Dockerfile
│   ├── entrypoint.sh            # Elevates postgres role for migrations
│   └── railway.json
├── realtime/                    # Elixir realtime subscriptions
│   ├── Dockerfile
│   └── railway.json
├── rest/                        # PostgREST
│   ├── Dockerfile
│   └── railway.json
└── storage/                     # Storage API
    ├── Dockerfile
    └── railway.json
```

## Key design decisions

### 1. Supabase/postgres role model

The upstream `supabase/postgres` image demotes the `postgres` role to non-superuser. The actual superuser is `supabase_admin`. GoTrue, Storage, and Realtime migrations connect as `postgres`, so the custom `postgres/entrypoint.sh` elevates `postgres` to `SUPERUSER` on startup and ensures the `_realtime` schema exists.

### 2. Kong declarative config

Kong runs in DB-less mode (`KONG_DATABASE=off`). `kong/entrypoint.sh` renders `kong.yml` at runtime using Railway private-domain env vars (`AUTH_HOST`, `REST_HOST`, etc.) injected automatically. A synthetic `/health` route with the `request-termination` plugin returns 200 for Railway's healthcheck.

### 3. MinIO binding

MinIO defaults to binding on a detected container IP. Railway's healthcheck probes `0.0.0.0`, so the start command forces `0.0.0.0:9000` and `0.0.0.0:9001`.

### 4. SMTP in auth

GoTrue crashes if `GOTRUE_SMTP_PORT` is an empty string. The template sets it to `2525` (a non-routable port) and enables `GOTRUE_MAILER_AUTOCONFIRM=true`, so signup emails are auto-confirmed without an SMTP server. To use real email, set `GOTRUE_SMTP_HOST`, `GOTRUE_SMTP_PORT`, `GOTRUE_SMTP_USER`, and `GOTRUE_SMTP_PASS` after deploy.

### 5. No Studio dashboard

Studio is intentionally excluded to keep the stack small. Admin operations should use the Supabase CLI or direct SQL against Postgres.

## Inter-service variable wiring

Private-domain references use Railway's auto-injected `RAILWAY_PRIVATE_DOMAIN` per service:

- `GOTRUE_DB_DATABASE_URL` → `postgres://${{ shared.POSTGRES_PASSWORD }}@${{ postgres.RAILWAY_PRIVATE_DOMAIN }}:5432/postgres?search_path=auth`
- `PGRST_DB_URI` → Postgres connection via private domain
- `DB_HOST` (realtime) → `${{ postgres.RAILWAY_PRIVATE_DOMAIN }}`
- Kong upstreams → `${{ auth.RAILWAY_PRIVATE_DOMAIN }}`, `${{ rest.RAILWAY_PRIVATE_DOMAIN }}`, etc.
- Storage S3 backend → `${{ minio.RAILWAY_PRIVATE_DOMAIN }}:9000`

## Local development / maintenance

```bash
# Clone
git clone https://github.com/INAPP-Mobile/railway-supabase-lite.git
cd railway-supabase-lite

# Link to the Railway project
railway link

# Redeploy a single service after config changes
railway redeploy --service <service-name> --yes

# View logs for a service
railway logs --service <service-name>
```

## Troubleshooting

### All services show FAILED but logs look fine

Railway may not detect the listening port. The template sets a `PORT` env var on each service, but if you deploy from the repo root with a root `railway.json` that lacks `deploy.port`, you may need to set `PORT` manually:

```bash
railway variables set PORT=9000 --service minio
```

### "permission denied for schema auth" in auth/storage/realtime

The custom postgres entrypoint must run successfully. Check the postgres logs:

```bash
railway logs --service postgres
```

You should see `ALTER ROLE postgres WITH SUPERUSER` succeed. If it fails, the `supabase_admin` password may not match `POSTGRES_PASSWORD`.

### Kong returns 404 for `/health`

Kong returns 404 for unmatched routes by design. Do not change the healthcheck path to `/`; the `kong/entrypoint.sh` defines a `/health` route that always returns 200.

### Realtime crashes with "APP_NAME not available"

Set `APP_NAME=realtime` on the realtime service.

### Postgres fails with stale `postmaster.pid`

The postgres entrypoint removes `/var/lib/postgresql/data/pgdata/postmaster.pid` on startup.

## Roadmap / not implemented

- [ ] Supabase Studio UI (would add significant resource cost)
- [ ] Supavisor connection pooler
- [ ] External SMTP provider instructions
- [ ] Backups (use Railway scheduled backups on the postgres volume)

## License

This template is MIT-licensed. All upstream images retain their respective licenses (AGPL/Apache/etc.).
