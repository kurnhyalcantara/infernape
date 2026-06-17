.PHONY: up down logs ps status restart clean help kong-bootstrap kong-sync kong-logs kong-manager demo-up demo-down

## help: Show this help message
help:
	@echo "Infernape - Local API Platform (Kong Gateway + Postgres + Redis)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'

## up: Start the full platform (Postgres + Redis + Kong + Manager)
up:
	@echo "Starting platform..."
	@docker compose up -d
	@echo ""
	@echo "Platform ready:"
	@echo "  Postgres:      localhost:$${POSTGRES_PORT:-5432}"
	@echo "  Redis:         localhost:$${REDIS_PORT:-6379}"
	@echo "  Kong proxy:    http://localhost:$${KONG_PROXY_PORT:-8000}"
	@echo "  Kong admin:    http://localhost:$${KONG_ADMIN_PORT:-8001} (loopback only)"
	@echo "  Kong Manager:  http://localhost:$${KONG_MANAGER_PORT:-8002}"

## down: Stop all services
down:
	@docker compose down

## logs: Follow logs for all services
logs:
	@docker compose logs -f

## ps: Show running containers
ps:
	@docker compose ps

## status: Check health of all services
status:
	@echo "=== Service Health ==="
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

## restart: Restart the platform
restart: down up

## kong-bootstrap: Run Kong database migrations (idempotent)
kong-bootstrap:
	@docker compose run --rm kong-migrations kong migrations bootstrap

## kong-sync: Re-apply the Git baseline (kong/kong.yaml) into Kong
kong-sync:
	@docker compose up -d kong-deck
	@docker compose logs kong-deck

## kong-logs: Follow Kong gateway logs
kong-logs:
	@docker compose logs -f kong

## kong-manager: Print the Kong Manager URL
kong-manager:
	@echo "Kong Manager: http://localhost:$${KONG_MANAGER_PORT:-8002}"

## demo-up: Start the demo echo upstream (visualize header injection)
demo-up:
	@docker compose --profile demo up -d echo
	@echo "Demo route: curl http://localhost:$${KONG_PROXY_PORT:-8000}/api/echo -H 'Authorization: Bearer <jwt>'"

## demo-down: Stop the demo echo upstream
demo-down:
	@docker compose --profile demo rm -sf echo

## clean: Stop everything and remove volumes (DESTRUCTIVE)
clean:
	@echo "WARNING: This will delete all data volumes!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker compose --profile demo down -v
	@echo "All data removed."
