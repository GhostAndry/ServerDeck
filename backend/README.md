# ServerDeck Backend Agent

The lightweight Go backend agent for **ServerDeck** running on the host server (`srv-01`). It provides REST APIs and real-time WebSockets to monitor system metrics (CPU, RAM, Disks, Network), manage Docker containers, probe self-hosted services, and stream live events to the ServerDeck SwiftUI iOS app.

---

## Architecture

```
iPhone (ServerDeck / SwiftUI)
          │
          │ HTTPS / Tailscale
          ▼
┌──────────────────────────────┐
│ Docker: serverdeck-backend   │
│                              │
│ REST API + WebSocket         │
│ Autenticazione (Bearer Token)│
│ Docker Engine API Client     │
│ Metriche Host (gopsutil)     │
└──────────────┬───────────────┘
               │
               │ /var/run/docker.sock
               ▼
          Docker Engine
               │
       ┌───────┴────────┐
       │                │
   Container       Altri stack
   ServerDeck      OpenWebUI, Films...
```

---

## Features

- **Host Overview**: Hostname, OS, Uptime, CPU (cores, model, temperature, usage %), RAM, Disk storage (`/` and `/mnt/DATA`), and Network I/O throughput rates.
- **Docker Management**: List containers, real-time stats, streaming logs (with timestamps and demuxing), and start/stop/restart container actions.
- **Auto Mock/Simulation Mode**: Automatically switches to an in-memory mock container manager if the Docker daemon is unreachable or during local macOS development.
- **Services Homepage**: Probes configured homelab services (`config/services.yml`) concurrently with latency and HTTP status codes.
- **Real-Time WebSocket**: Streams `host_tick` updates every 2–3 seconds and live `container_event` notifications on state changes.
- **Security**: Token-based authentication (`Authorization: Bearer <TOKEN>` or `X-API-Key: <TOKEN>`) with constant-time comparison, CORS support, and dropped Linux capabilities.

---

## API Endpoints

All endpoints except `/healthz` require Bearer or X-API-Key token authentication.

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/healthz` | Unauthenticated health status check |
| `GET` | `/api/v1/host` | Host metrics (CPU, RAM, Disks, Net rates, Containers summary) |
| `GET` | `/api/v1/containers` | List all containers with state, ports, stack, and resource usage |
| `GET` | `/api/v1/containers/{id}/stats` | Detailed stats for a single container (CPU, RAM, Net, Block I/O) |
| `GET` | `/api/v1/containers/{id}/logs?tail=200&timestamps=true` | Container logs |
| `POST` | `/api/v1/containers/{id}/start` | Start container |
| `POST` | `/api/v1/containers/{id}/stop` | Stop container |
| `POST` | `/api/v1/containers/{id}/restart` | Restart container |
| `GET` | `/api/v1/services` | Probe and return status of configured homelab services |
| `GET` | `/api/v1/events` | WebSocket streaming `host_tick` and `container_event` |

---

## Configuration

Configurable via environment variables:

| Variable | Default | Description |
|---|---|---|
| `SERVERDECK_LISTEN` | `0.0.0.0:8080` | Listen host and port |
| `SERVERDECK_TOKEN` | `serverdeck-dev-secret-token` | Secret authentication token |
| `SERVERDECK_CONFIG` | `config/services.yml` | Path to services YAML configuration |
| `SERVERDECK_DB` | `data/serverdeck.db` | Path to SQLite database |
| `SERVERDECK_MOCK_DOCKER` | `false` | Force mock Docker simulation mode |
| `SERVERDECK_MOCK_METRICS` | `false` | Force mock metrics collector |
| `SERVERDECK_TICK_INTERVAL_SEC` | `2` | WebSocket host_tick broadcast interval (seconds) |
| `SERVERDECK_CORS_ALLOWED_ORIGINS` | `*` | Allowed CORS origins for development |
| `HOST_PROC` | `""` | Host `/proc` mount point when running inside Docker |
| `HOST_SYS` | `""` | Host `/sys` mount point when running inside Docker |

---

## Local Development

### 1. Run Tests
```bash
go test -v ./...
```

### 2. Run Locally
```bash
go run cmd/server/main.go
```
The server will start at `http://0.0.0.0:8080`. If Docker is not running locally (e.g. on macOS without Docker Desktop active), it automatically falls back to mock simulation mode.

### 3. Test with cURL
```bash
# Health check (unauthenticated)
curl -i http://localhost:8080/healthz

# Host overview
curl -H "Authorization: Bearer serverdeck-dev-secret-token" http://localhost:8080/api/v1/host

# List containers
curl -H "Authorization: Bearer serverdeck-dev-secret-token" http://localhost:8080/api/v1/containers

# Restart a container
curl -X POST -H "Authorization: Bearer serverdeck-dev-secret-token" http://localhost:8080/api/v1/containers/c1a2b3c4d5e6/restart

# Services probe
curl -H "Authorization: Bearer serverdeck-dev-secret-token" http://localhost:8080/api/v1/services
```

---

## Docker Deployment

To build and run using Docker Compose:

```bash
docker compose up -d --build
```
