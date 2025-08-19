# Variables
DB_USER = social_user
DB_PASSWORD = social_password
DB_NAME = social_db
DB_HOST = localhost
DB_PORT = 5432
DB_URL = postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=disable
MIGRATIONS_PATH = ./cmd/migrate/migrations

# Colors for output
GREEN = \033[0;32m
NC = \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  ${GREEN}%-20s${NC} %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# Database migrations
.PHONY: migrate-create
migrate-create: ## Create a new migration (usage: make migrate-create create_users)
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please provide a migration name. Usage: make migrate-create migration_name"; \
		exit 1; \
	fi
	migrate create -seq -ext sql -dir $(MIGRATIONS_PATH) $(filter-out $@,$(MAKECMDGOALS))

.PHONY: migrate-up
migrate-up: ## Run all up migrations
	migrate -path $(MIGRATIONS_PATH) -database "$(DB_URL)" up

.PHONY: migrate-down
migrate-down: ## Run all down migrations
	migrate -path $(MIGRATIONS_PATH) -database "$(DB_URL)" down

.PHONY: migrate-down-one
migrate-down-one: ## Rollback one migration
	migrate -path $(MIGRATIONS_PATH) -database "$(DB_URL)" down 1

.PHONY: migrate-force
migrate-force: ## Force migration to specific version (usage: make migrate-force 1)
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please provide a version. Usage: make migrate-force 1"; \
		exit 1; \
	fi
	migrate -path $(MIGRATIONS_PATH) -database "$(DB_URL)" force $(filter-out $@,$(MAKECMDGOALS))

.PHONY: migrate-version
migrate-version: ## Show current migration version
	migrate -path $(MIGRATIONS_PATH) -database "$(DB_URL)" version

# Docker commands
.PHONY: docker-up
docker-up: ## Start Docker containers
	docker-compose up -d

.PHONY: docker-down
docker-down: ## Stop Docker containers
	docker-compose down

.PHONY: docker-logs
docker-logs: ## Show Docker container logs
	docker-compose logs -f postgres

.PHONY: docker-clean
docker-clean: ## Remove Docker containers and volumes
	docker-compose down -v

# Database commands
.PHONY: db-shell
db-shell: ## Connect to PostgreSQL shell
	docker exec -it social_postgres psql -U $(DB_USER) -d $(DB_NAME)

.PHONY: db-reset
db-reset: docker-down docker-clean docker-up ## Reset database (removes all data)
	@echo "Waiting for database to be ready..."
	@sleep 3
	@echo "Database reset complete"

# Application commands
.PHONY: run
run: ## Run the application
	go run cmd/api/*.go

.PHONY: build
build: ## Build the application
	go build -o bin/social cmd/api/*.go

.PHONY: test
test: ## Run tests
	go test -v ./...

.PHONY: test-coverage
test-coverage: ## Run tests with coverage
	go test -v -cover ./...

.PHONY: lint
lint: ## Run linter
	golangci-lint run

.PHONY: fmt
fmt: ## Format code
	go fmt ./...

.PHONY: mod-tidy
mod-tidy: ## Clean up module dependencies
	go mod tidy

.PHONY: mod-verify
mod-verify: ## Verify module dependencies
	go mod verify

# Development setup
.PHONY: setup
setup: docker-up install-tools ## Setup development environment
	@echo "Development environment setup complete"

.PHONY: install-tools
install-tools: ## Install development tools
	@echo "Installing migrate tool..."
	@go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	@echo "Installing golangci-lint..."
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo "Installing air for hot reload..."
	@go install github.com/air-verse/air@latest
	@echo "Tools installation complete"

.PHONY: dev
dev: ## Run application with hot reload (requires air)
	air

.PHONY: clean
clean: ## Clean build artifacts
	rm -rf bin/
	rm -rf tmp/

# All command
.PHONY: all
all: docker-up migrate-up run ## Start everything (docker, migrations, app)

# Catch-all target to handle arguments
%:
	@: