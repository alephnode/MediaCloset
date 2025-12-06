# MediaCloset API Makefile

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GORUN=$(GOCMD) run
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod
GOFMT=$(GOCMD) fmt

# Binary name
BINARY_NAME=server
BINARY_PATH=./bin/$(BINARY_NAME)

# Main package
MAIN_PACKAGE=./cmd/server

# Docker
DOCKER_IMAGE=mediacloset-api
DOCKER_TAG=latest

.PHONY: all build run test clean generate fmt lint docker-build docker-run deps tidy help

# Default target
all: build

## build: Build the server binary
build:
	@echo "Building..."
	@mkdir -p bin
	$(GOBUILD) -o $(BINARY_PATH) $(MAIN_PACKAGE)
	@echo "Built $(BINARY_PATH)"

## run: Run the server
run:
	@echo "Running server..."
	$(GORUN) $(MAIN_PACKAGE)

## test: Run all tests
test:
	@echo "Running tests..."
	$(GOTEST) -v ./...

## test-coverage: Run tests with coverage report
test-coverage:
	@echo "Running tests with coverage..."
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

## clean: Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf bin/
	@rm -f coverage.out coverage.html
	@echo "Cleaned"

## generate: Run gqlgen to generate GraphQL code
generate:
	@echo "Generating GraphQL code..."
	$(GORUN) github.com/99designs/gqlgen generate
	@echo "Generated GraphQL code"

## fmt: Format Go code
fmt:
	@echo "Formatting code..."
	$(GOFMT) ./...

## lint: Run linter (requires golangci-lint)
lint:
	@echo "Running linter..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "golangci-lint not installed. Install with: brew install golangci-lint"; \
	fi

## deps: Download dependencies
deps:
	@echo "Downloading dependencies..."
	$(GOMOD) download

## tidy: Tidy go.mod
tidy:
	@echo "Tidying go.mod..."
	$(GOMOD) tidy

## docker-build: Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

## docker-run: Run Docker container
docker-run:
	@echo "Running Docker container..."
	docker run -p 8080:8080 --env-file .env $(DOCKER_IMAGE):$(DOCKER_TAG)

## dev: Run with hot reload (requires air)
dev:
	@echo "Running with hot reload..."
	@if command -v air >/dev/null 2>&1; then \
		air; \
	else \
		echo "air not installed. Install with: go install github.com/air-verse/air@latest"; \
		echo "Falling back to regular run..."; \
		$(MAKE) run; \
	fi

## help: Show this help message
help:
	@echo "MediaCloset API - Available targets:"
	@echo ""
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/ /'
