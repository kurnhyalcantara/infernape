.PHONY: up down logs ps status restart clean help

## help: Show this help message
help:
	@echo "Infernape - Centralized Infrastructure for Koer Services"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'

## up: Start core infrastructure (Postgres + Redis)
up:
	@echo "Starting infrastructure..."
	@docker compose up -d
	@echo ""
	@echo "Infrastructure ready:"
	@echo "  Postgres: localhost:$${POSTGRES_PORT:-5432}"
	@echo "  Redis:    localhost:$${REDIS_PORT:-6379}"

## down: Stop all infrastructure services
down:
	@docker compose down

## logs: Follow infrastructure logs
logs:
	@docker compose logs -f

## ps: Show running containers
ps:
	@docker compose ps

## status: Check health of all services
status:
	@echo "=== Service Health ==="
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

## restart: Restart all infrastructure
restart: down up

## clean: Stop everything and remove volumes (DESTRUCTIVE)
clean:
	@echo "WARNING: This will delete all data volumes!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker compose down -v
	@echo "All data removed."
