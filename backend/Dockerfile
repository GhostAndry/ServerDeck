# Build stage
FROM golang:alpine AS builder

WORKDIR /build

RUN apk add --no-cache git ca-certificates tzdata

# Cache go modules
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s -extldflags '-static'" \
    -o /serverdeck cmd/server/main.go

# Runtime stage
FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata dbus

WORKDIR /app

# Copy binary from builder
COPY --from=builder /serverdeck /app/serverdeck

# Copy default config template
COPY config/services.yml /app/config/services.yml

# Environment defaults
ENV SERVERDECK_LISTEN="0.0.0.0:8080" \
    SERVERDECK_CONFIG="/app/config/services.yml" \
    SERVERDECK_DB="/app/data/serverdeck.db" \
    TZ="Europe/Rome"

EXPOSE 8080

ENTRYPOINT ["/app/serverdeck"]
