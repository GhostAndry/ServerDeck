# ServerDeck Shared Specification & API Contract

This document defines the unified API, data models, and architectural patterns shared between the **ServerDeck Go Backend** and the **ServerDeck SwiftUI iOS App**.

---

## 1. Authentication & Security
- **Header:** `Authorization: Bearer <TOKEN>` or `X-API-Key: <TOKEN>`
- **HTTP status on failure:** `401 Unauthorized` with body `{"error": "Unauthorized"}`
- Network model: Private access via Tailscale / WireGuard (e.g. `https://srv-01.tailscale-net:8080`).

---

## 2. API Endpoints

### 2.1 Host Overview
- **Endpoint:** `GET /api/v1/host`
- **Response `200 OK`**:
```json
{
  "hostname": "srv-01",
  "os": "Debian GNU/Linux 12 (bookworm)",
  "uptime_seconds": 345600,
  "cpu": {
    "usage_percent": 18.5,
    "cores": 4,
    "model": "Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz",
    "temperature_celsius": 42.5
  },
  "memory": {
    "total_bytes": 16777216000,
    "used_bytes": 8388608000,
    "free_bytes": 8388608000,
    "usage_percent": 50.0
  },
  "disks": [
    {
      "mount_point": "/",
      "filesystem": "/dev/sda1",
      "total_bytes": 107374182400,
      "used_bytes": 48318382080,
      "free_bytes": 59055800320,
      "usage_percent": 45.0
    },
    {
      "mount_point": "/mnt/DATA",
      "filesystem": "/dev/sdb1",
      "total_bytes": 2000398934016,
      "used_bytes": 1440287232491,
      "free_bytes": 560111701525,
      "usage_percent": 72.0
    }
  ],
  "network": {
    "bytes_recv_rate": 1048576,
    "bytes_sent_rate": 524288
  },
  "containers_summary": {
    "total": 12,
    "running": 10,
    "stopped": 2,
    "unhealthy": 0
  }
}
```

### 2.2 Container Management
- **Endpoint:** `GET /api/v1/containers`
- **Response `200 OK`**: Array of containers:
```json
[
  {
    "id": "c1a2b3c4d5e6",
    "name": "openwebui",
    "image": "ghcr.io/open-webui/open-webui:main",
    "state": "running",
    "status": "Up 3 days (healthy)",
    "health": "healthy",
    "stack": "OpenWebUI",
    "created_at": 1700000000,
    "ports": ["8080:8080"],
    "cpu_percent": 2.4,
    "memory_usage_bytes": 268435456,
    "memory_limit_bytes": 16777216000
  }
]
```

- **Endpoint:** `GET /api/v1/containers/{id}/stats`
- **Response `200 OK`**:
```json
{
  "id": "c1a2b3c4d5e6",
  "name": "openwebui",
  "cpu_percent": 2.4,
  "memory_usage_bytes": 268435456,
  "memory_limit_bytes": 16777216000,
  "memory_percent": 1.6,
  "network_rx_bytes": 52428800,
  "network_tx_bytes": 18874368,
  "block_read_bytes": 1048576,
  "block_write_bytes": 4194304
}
```

- **Endpoint:** `GET /api/v1/containers/{id}/logs?tail=200&timestamps=true`
- **Response `200 OK`**:
```json
{
  "container_id": "c1a2b3c4d5e6",
  "lines": [
    "2026-03-30T10:00:00Z [info] Server started on port 8080",
    "2026-03-30T10:00:05Z [info] Connected to database"
  ]
}
```

- **Container Actions:**
  - `POST /api/v1/containers/{id}/start`
  - `POST /api/v1/containers/{id}/stop`
  - `POST /api/v1/containers/{id}/restart`
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "Container restarted successfully"
}
```

### 2.3 Services Homepage
- **Endpoint:** `GET /api/v1/services`
- **Response `200 OK`**:
```json
[
  {
    "id": "openwebui",
    "name": "OpenWebUI",
    "url": "http://srv-01:8080",
    "icon": "bubble.left.and.bubble.right.fill",
    "category": "AI",
    "status": "online",
    "response_time_ms": 32,
    "status_code": 200
  },
  {
    "id": "portainer",
    "name": "Portainer",
    "url": "https://srv-01:9443",
    "icon": "shippingbox.fill",
    "category": "Management",
    "status": "online",
    "response_time_ms": 15,
    "status_code": 200
  },
  {
    "id": "qbittorrent",
    "name": "qBittorrent",
    "url": "http://srv-01:8081",
    "icon": "arrow.down.circle.fill",
    "category": "Media",
    "status": "online",
    "response_time_ms": 28,
    "status_code": 200
  }
]
```

### 2.4 Real-Time Events (WebSocket)
- **Endpoint:** `GET /api/v1/events` (Upgrade: websocket, Bearer token in query `?token=...` or Header)
- Sends JSON events:
```json
{
  "type": "host_tick",
  "timestamp": 1700000010,
  "data": { ...host overview... }
}
```
or
```json
{
  "type": "container_event",
  "timestamp": 1700000012,
  "data": {
    "container_id": "c1a2b3c4d5e6",
    "action": "restart",
    "status": "running"
  }
}
```

### 2.5 Host Control & Maintenance
- **Reboot Host:** `POST /api/v1/host/reboot`
  - Body: `{}`
  - Response `200 OK`: `{"success": true, "action": "reboot", "message": "Host reboot scheduled in 3 seconds"}`
- **Shutdown Host:** `POST /api/v1/host/shutdown`
  - Body: `{}`
  - Response `200 OK`: `{"success": true, "action": "shutdown", "message": "Host shutdown scheduled in 3 seconds"}`
- **Docker System Prune:** `POST /api/v1/system/prune`
  - Response `200 OK`: `{"containers_deleted": 2, "images_deleted": 4, "space_reclaimed_bytes": 1425800000}`
- **Restart Unhealthy Containers:** `POST /api/v1/system/restart-unhealthy`
  - Response `200 OK`: `{"success": true, "restarted_count": 2, "containers": ["c1", "c2"], "message": "Restarted 2 unhealthy or exited containers"}`
- **System Diagnostics:** `GET /api/v1/system/diagnostics`
  - Response `200 OK`: kernel version, platform, memory & swap breakdown, partition details, load average.

---

## 3. Directory Layout
```
ServerDeck/
├── SHARED_SPEC.md        # This specification
├── backend/              # Go REST + WebSocket server & Dockerfile & compose
│   ├── cmd/server/main.go
│   ├── internal/
│   │   ├── api/          # HTTP & WebSocket routing & handlers
│   │   ├── config/       # YAML config & environment
│   │   ├── docker/       # Docker Engine API client wrapper
│   │   ├── metrics/      # Host CPU/RAM/Disk/Net metrics collector
│   │   ├── services/     # Health check prober for services
│   │   └── auth/         # Token validation middleware
│   ├── config/
│   │   └── services.yml  # Configured services list
│   ├── Dockerfile
│   ├── compose.yml
│   └── go.mod
└── ios/                  # Native SwiftUI iOS Application
    ├── ServerDeck/
    │   ├── App/
    │   ├── Models/
    │   ├── Services/
    │   │   ├── APIClient.swift
    │   │   ├── WebSocketManager.swift
    │   │   ├── KeychainService.swift
    │   │   └── MockDataProvider.swift
    │   ├── ViewModels/
    │   │   ├── OverviewViewModel.swift
    │   │   ├── ContainersViewModel.swift
    │   │   ├── ContainerDetailViewModel.swift
    │   │   ├── ServicesViewModel.swift
    │   │   └── SettingsViewModel.swift
    │   └── Views/
    │       ├── MainTabView.swift
    │       ├── Overview/
    │       ├── Containers/
    │       ├── Services/
    │       ├── QuickActions/
    │       └── Settings/
    ├── ServerDeck.xcodeproj / Package.swift
    └── README.md
```
