.PHONY: all test build-backend run-backend test-backend build-ios

all: build-backend

build-backend:
	@echo "==> Building Go backend..."
	cd backend && go build -o bin/serverdeck cmd/server/main.go

run-backend:
	@echo "==> Running Go backend..."
	cd backend && go run cmd/server/main.go

test-backend:
	@echo "==> Testing Go backend..."
	cd backend && go test -v ./...

build-ios:
	@echo "==> Building iOS Swift package..."
	cd ios && swift build

test: test-backend
