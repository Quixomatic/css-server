# ============================================
# Counter-Strike: Source Server - Makefile
# ============================================
# Common commands for building and running the server

.PHONY: help build run stop logs shell test update clean

# Default target
help:
	@echo "Counter-Strike: Source Server - Available Commands"
	@echo ""
	@echo "  make build      - Build the Docker image"
	@echo "  make run        - Start the server (detached)"
	@echo "  make run-it     - Start the server (interactive/foreground)"
	@echo "  make stop       - Stop the server"
	@echo "  make restart    - Restart the server"
	@echo "  make logs       - View server logs (follow mode)"
	@echo "  make shell      - Open a shell in the container"
	@echo "  make test       - Run the test suite"
	@echo "  make update     - Update CS:S game files"
	@echo "  make rcon       - Connect to RCON (requires RCON_PASSWORD)"
	@echo "  make clean      - Remove container and image"
	@echo "  make clean-data - Remove all data (WARNING: deletes everything)"
	@echo ""
	@echo "  make download-plugins - Download MetaMod/SourceMod"
	@echo ""

# Build the Docker image
build:
	docker build -t css-server:latest .

# Build with no cache
build-fresh:
	docker build --no-cache -t css-server:latest .

# Run the server (detached)
run:
	docker compose up -d

# Run the server (interactive - see output)
run-it:
	docker compose up

# Stop the server
stop:
	docker compose down

# Restart the server
restart:
	docker compose restart

# View logs
logs:
	docker compose logs -f

# Open shell in container
shell:
	docker compose exec css-server bash

# Run tests
test: build
	docker run --rm css-server:latest /home/steam/tests/server-test.sh

# Update game files
update:
	docker compose exec css-server /home/steam/entrypoint.sh update

# Quick run without compose (for testing)
run-quick:
	docker run -it --rm --net=host \
		-e CSS_HOSTNAME="Test Server" \
		-e RCON_PASSWORD="testpass" \
		-e CSS_BOT_QUOTA=4 \
		css-server:latest

# Clean up container and image
clean:
	docker compose down --rmi local 2>/dev/null || true
	docker rmi css-server:latest 2>/dev/null || true

# Clean ALL data (dangerous!)
clean-data:
	@echo "WARNING: This will delete all server data!"
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ]
	docker compose down -v
	rm -rf ./data

# Download MetaMod and SourceMod
download-plugins:
	./scripts/download-plugins.sh

# Show server status
status:
	@docker compose ps
	@echo ""
	@docker compose exec css-server pgrep -a srcds_linux 2>/dev/null || echo "Server not running"

# Validate configuration
validate:
	@echo "Validating Dockerfile..."
	docker build --check .
	@echo ""
	@echo "Validating compose.yaml..."
	docker compose config --quiet && echo "compose.yaml is valid"
