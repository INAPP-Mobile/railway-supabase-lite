# Supabase Lite (Railway Template)

Minimal, cost-optimized Supabase self-host stack. Unlike the full 12-service Supabase template (postgres, kong, auth, rest, realtime, storage, imgproxy, meta, functions, analytics, studio, supavisor) that needs 4-8GB RAM, Lite runs 7 core services in ~1.5GB RAM for $10-15/mo.

## Architecture

```
Client → Kong (public :8000) → [auth, rest, realtime, storage] → Postgres + MinIO (S3 backend for storage)
```

**Stripped services:** Studio, imgproxy, postgres-meta, edge-runtime, logflare/analytics, supavisor, vector (not supported on Railway anyway). pgvector stays.

## Services

| Service   | Image                                    | Port(s)      | Purpose                     |
|-----------|------------------------------------------|--------------|-----------------------------|
| postgres  | `supabase/postgres:15.8.1.085`           | 5432         | PostgreSQL DB w/ extensions |
| kong      | `kong:3.9.1`                             | 8000 (pub)   | API gateway + routing       |
| auth      | `supabase/gotrue:v2.186.0`              | 9999         | Auth service (GoTrue)       |
| rest      | `postgrest/postgrest:v14.8`             | 3000         | Auto-generated REST API     |
| realtime  | `supabase/realtime:v2.76.5`             | 4000         | Realtime subscriptions      |
| storage   | `supabase/storage-api:v1.48.26`         | 5000         | S3-compatible storage API   |
| minio     | `minio/minio:RELEASE.2024-11-07T00-52-20Z` | 9000/9001 | MinIO S3 backend            |

## Usage

After deploying, your public Supabase URL is:

```
https://<kong-railway-subdomain>.up.railway.app
```

Connect with the JS client:

```js
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://<your-kong-subdomain>.up.railway.app',
  '<ANON_KEY>'  // auto-generated, view in Railway variables
)
```

## Volume Sizing

| Service  | Mount Path              | Size  | Notes                              |
|----------|-------------------------|-------|------------------------------------|
| postgres | `/var/lib/postgresql`   | 10 GB | Parent of PGDATA to avoid lost+found collision |
| minio    | `/data`                 | 5 GB  | MinIO object store                 |

## Environment Variables

See `template-vars.json` for user-facing configuration. All secrets use `${{ secret(N) }}` — no hardcoded credentials.

### Shared Variables (root-level)

- `POSTGRES_PASSWORD` — master DB password, referenced by all services
- `JWT_SECRET` — HS256 signing key for `ANON_KEY` and `SERVICE_ROLE_KEY` (generate with `openssl rand -base64 32`)
- `ANON_KEY` — public client JWT
- `SERVICE_ROLE_KEY` — server-side full-access JWT
- `DASHBOARD_USERNAME` — defaults to `supabase`
- `DASHBOARD_PASSWORD` — auto-generated secret

### Inter-Service Communication

All inter-service traffic uses Railway private networking via `${{ service.RAILWAY_PRIVATE_DOMAIN }}` — no public endpoints for internal calls.

## Deployment

```bash
# 1. Create Railway project from template
railway templates create supabase-lite

# 2. Deploy
railway up
```

## Self-Identification

- **Model:** opencode-zen/laguna-s-2.1-free (via omniroute; previously stepfun/step-3.7-flash:free, deepseek-v4-flash:free)
