# Makefile for Harbor
# Fork of goharbor/harbor

PROJECT_NAME := harbor
GO_VERSION := 1.21
DOCKER_COMPOSE_FILE := docker-compose.yml

# Version information
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Go build flags
LDFLAGS := -ldflags "-X github.com/goharbor/harbor/src/pkg/version.ReleaseVersion=$(VERSION) \
	-X github.com/goharbor/harbor/src/pkg/version.GitCommit=$(GIT_COMMIT) \
	-X github.com/goharbor/harbor/src/pkg/version.BuildDate=$(BUILD_DATE)"

# Directories
SRC_DIR := ./src
BIN_DIR := ./bin
TEST_DIR := ./tests

.PHONY: all build test lint clean docker-build docker-push help

## all: Build all components
all: build

## build: Build all Go binaries
build:
	@echo "Building Harbor components..."
	@mkdir -p $(BIN_DIR)
	go build $(LDFLAGS) -o $(BIN_DIR)/harbor-core $(SRC_DIR)/core/...
	go build $(LDFLAGS) -o $(BIN_DIR)/harbor-jobservice $(SRC_DIR)/jobservice/...
	go build $(LDFLAGS) -o $(BIN_DIR)/harbor-registryctl $(SRC_DIR)/registryctl/...
	@echo "Build complete."

## test: Run unit tests
test:
	@echo "Running unit tests..."
	go test ./src/... -v -race -count=1 -timeout 300s

## test-coverage: Run tests with coverage report
test-coverage:
	@echo "Running tests with coverage..."
	go test ./src/... -coverprofile=coverage.out -covermode=atomic
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

## lint: Run linters
lint:
	@echo "Running linters..."
	golangci-lint run ./src/...

## fmt: Format Go code
fmt:
	@echo "Formatting Go code..."
	gofmt -w $(SRC_DIR)
	goimports -w $(SRC_DIR)

## vet: Run go vet
vet:
	@echo "Running go vet..."
	go vet ./src/...

## docker-build: Build Docker images
docker-build:
	@echo "Building Docker images for version $(VERSION)..."
	docker build -t goharbor/harbor-core:$(VERSION) -f make/photon/core/Dockerfile .
	docker build -t goharbor/harbor-jobservice:$(VERSION) -f make/photon/jobservice/Dockerfile .
	docker build -t goharbor/harbor-portal:$(VERSION) -f make/photon/portal/Dockerfile .

## docker-push: Push Docker images to registry
docker-push: docker-build
	@echo "Pushing Docker images..."
	docker push goharbor/harbor-core:$(VERSION)
	docker push goharbor/harbor-jobservice:$(VERSION)
	docker push goharbor/harbor-portal:$(VERSION)

## up: Start Harbor using docker-compose
up:
	docker-compose -f $(DOCKER_COMPOSE_FILE) up -d

## down: Stop Harbor
down:
	docker-compose -f $(DOCKER_COMPOSE_FILE) down

## clean: Remove build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BIN_DIR)
	rm -f coverage.out coverage.html
	@echo "Clean complete."

## deps: Download Go module dependencies
deps:
	go mod download
	go mod tidy

## generate: Run go generate
generate:
	go generate ./src/...

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' Makefile | sed 's/## /  /'
