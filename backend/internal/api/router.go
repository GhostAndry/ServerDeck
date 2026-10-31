package api

import (
	"net/http"

	"github.com/serverdeck/serverdeck-backend/internal/auth"
)

// SetupRouter creates the HTTP handler routing all API endpoints.
func SetupRouter(api *ServerAPI, authMw *auth.Middleware) http.Handler {
	mux := http.NewServeMux()

	// 1. Health check (unauthenticated)
	mux.HandleFunc("GET /healthz", api.HealthCheckHandler)

	// 2. Host Overview
	mux.HandleFunc("GET /api/v1/host", api.HostHandler)

	// 3. Container Management
	mux.HandleFunc("GET /api/v1/containers", api.ContainersHandler)
	mux.HandleFunc("GET /api/v1/containers/{id}/stats", api.ContainerStatsHandler)
	mux.HandleFunc("GET /api/v1/containers/{id}/logs", api.ContainerLogsHandler)
	mux.HandleFunc("POST /api/v1/containers/{id}/start", api.ContainerStartHandler)
	mux.HandleFunc("POST /api/v1/containers/{id}/stop", api.ContainerStopHandler)
	mux.HandleFunc("POST /api/v1/containers/{id}/restart", api.ContainerRestartHandler)

	// 4. Services Homepage
	mux.HandleFunc("GET /api/v1/services", api.ServicesHandler)
	mux.HandleFunc("POST /api/v1/services", api.AddServiceHandler)
	mux.HandleFunc("DELETE /api/v1/services/{id}", api.DeleteServiceHandler)

	// 5. Host Control & System Maintenance
	mux.HandleFunc("POST /api/v1/host/reboot", api.HostRebootHandler)
	mux.HandleFunc("POST /api/v1/host/shutdown", api.HostShutdownHandler)
	mux.HandleFunc("POST /api/v1/host/exec", api.HostExecHandler)
	mux.HandleFunc("POST /api/v1/system/prune", api.SystemPruneHandler)
	mux.HandleFunc("POST /api/v1/system/restart-unhealthy", api.SystemRestartUnhealthyHandler)
	mux.HandleFunc("GET /api/v1/system/diagnostics", api.SystemDiagnosticsHandler)

	// 6. WebSocket Real-time events
	mux.HandleFunc("GET /api/v1/events", api.EventsWebSocketHandler)

	// Apply authentication and CORS middleware
	var handler http.Handler = mux
	if authMw != nil {
		handler = authMw.RequireAuth(handler)
		handler = authMw.CORS(handler)
	}

	return handler
}
