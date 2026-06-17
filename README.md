# Infernape

Local **API platform** for the **Koer** microservices ecosystem. Fronts the services with
**Kong Gateway OSS** and centralizes authentication in the **araquanid** auth service, while
managing the shared databases and cache. Everything starts with one command.

## Services

| Service | Container | Port | Description |
|---|---|---|---|
| Kong Gateway (OSS) | `koer-kong` | 8000 / 8443 | API gateway — the single public entry point |
| Kong Admin API | `koer-kong` | 127.0.0.1:8001 | Control plane (loopback only) |
| Kong Manager (OSS) | `koer-kong` | 8002 | Web UI for services/routes/plugins/consumers |
| Kong database | `koer-kong-db` | *(internal)* | Kong control-plane state (dedicated Postgres) |
| PostgreSQL 16 | `koer-postgres` | 5432 | Shared application database server |
| Redis 7 | `koer-redis` | 6379 | Shared cache / session store |

Use **DBeaver** / **Redis Insight** to manage the data stores, and **Kong Manager**
(`http://localhost:8002`) to inspect the gateway.

## Authentication model

Kong does **not** validate JWTs. The custom `forward-auth` plugin calls araquanid's
`/auth/verify` endpoint per request and, on success, injects trusted headers for the upstream:

```
X-User-ID   X-User-Email   X-User-Role   X-User-Permissions
```

Downstream services trust these headers and never re-validate the token. Client-supplied
`X-User-*` headers are stripped at the gateway. See [docs/architecture.md](docs/architecture.md)
for the full flows, design decisions, and roadmap.

## Quick Start

```bash
# Copy environment config
cp .env.example .env

# Start the whole platform
docker compose up -d        # or: make up
```

On startup Kong's database is migrated and the Git baseline (`kong/kong.yaml`) is synced
automatically. The bootstrap order is:

```
kong-database → kong-migrations → kong → kong-deck (baseline sync)
```

## Gateway routes (baseline)

| Route | Upstream | Auth |
|---|---|---|
| `/api/auth/*` | araquanid | public (issues tokens) |
| `/api/product/*` | koer-product-service | forward-auth |
| `/api/task/*` | koer-task-service | forward-auth |
| `/api/echo/*` | echo (demo profile) | forward-auth |

> Baseline config is managed via decK with `--select-tag baseline`, so changes you make in Kong
> Manager survive re-syncs (Hybrid strategy). See [kong/README.md](kong/README.md).

## Try it (demo)

```bash
make demo-up      # start the echo upstream behind Kong

# No token → 401
curl -i http://localhost:8000/api/echo

# With a valid araquanid token → echo shows injected X-User-* headers
curl -s http://localhost:8000/api/echo -H "Authorization: Bearer <jwt>"
```

(The header-injection demo requires araquanid running on `koer-network` with its `/auth/verify`
endpoint.)

## Databases

The init script (`scripts/init-databases.sh`) creates one application database per service on
first run (Kong uses its own separate database). Configure via `POSTGRES_DATABASES` in `.env`:

```
POSTGRES_DATABASES=araquanid,koer_cash_management,koer_product,koer_task,koer_tax
```

Each service runs its own migrations against its database.

## Connecting Services

Services join the external `koer-network` and reach the platform by container name:

```yaml
services:
  app:
    networks:
      - koer-network

networks:
  koer-network:
    external: true
```

- **Postgres**: `koer-postgres:5432`
- **Redis**: `koer-redis:6379`
- Public traffic goes through **Kong**: `http://koer-kong:8000` (or `localhost:8000` from the host)

## Commands

| Command | Description |
|---|---|
| `make up` | Start the full platform |
| `make down` | Stop all services |
| `make status` | Health check |
| `make kong-sync` | Re-apply the Git baseline to Kong |
| `make kong-bootstrap` | Run Kong DB migrations (idempotent) |
| `make kong-logs` | Follow Kong gateway logs |
| `make demo-up` / `make demo-down` | Start / stop the demo echo upstream |
| `make clean` | Remove everything including data (destructive) |

## Service Ecosystem

```
infernape/          ← you are here (platform: gateway + data stores)
araquanid/          ← auth & authorization service (source of truth)
koer-cash-management/
koer-product-service/
koer-task-service/
koer-tax-service/
koer-base-protobuf/ ← shared proto definitions
```
