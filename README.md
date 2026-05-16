# Infernape

Centralized infrastructure for the **Koer** microservices ecosystem. Manages shared databases, caches, and admin tools so individual services don't spin up their own.

## Services

| Service | Container | Port | Description |
|---|---|---|---|
| PostgreSQL 16 | `koer-postgres` | 5432 | Shared database server |
| Redis 7 | `koer-redis` | 6379 | Shared cache / session store |

Use **DBeaver** and **Redis Insight** locally to manage databases.

## Network

All services attach to the `koer-network` Docker bridge network. Microservices connect to this external network to reach Postgres and Redis.

## Quick Start

```bash
# Copy environment config
cp .env.example .env

# Start core infrastructure
make up
```

## Databases

The init script (`scripts/init-databases.sh`) automatically creates one database per service on first run. Configure via `POSTGRES_DATABASES` in `.env`:

```
POSTGRES_DATABASES=araquanid,koer_cash_management,koer_product,koer_task,koer_tax
```

Each service runs its own migrations against its database.

## Connecting Services

Services should use `koer-network` as an external network in their `docker-compose.yml`:

```yaml
services:
  app:
    networks:
      - koer-network

networks:
  koer-network:
    external: true
```

And reference the infrastructure containers by name:
- **Postgres**: `koer-postgres:5432`
- **Redis**: `koer-redis:6379`

## Commands

| Command | Description |
|---|---|
| `make up` | Start Postgres + Redis |
| `make down` | Stop all services |
| `make logs` | Follow logs |
| `make status` | Health check |
| `make restart` | Restart infrastructure |
| `make clean` | Remove everything including data (destructive) |

## Service Ecosystem

```
infernape/          ← you are here (infrastructure)
araquanid/          ← auth & authorization service
koer-cash-management/
koer-product-service/
koer-task-service/
koer-tax-service/
koer-base-protobuf/ ← shared proto definitions
```
