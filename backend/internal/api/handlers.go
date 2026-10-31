package api

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/serverdeck/serverdeck-backend/internal/docker"
	"github.com/serverdeck/serverdeck-backend/internal/hostctrl"
	"github.com/serverdeck/serverdeck-backend/internal/metrics"
	"github.com/serverdeck/serverdeck-backend/internal/services"
)

var identifierRegex = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_.-]*$`)

// validateIdentifier prevents path injection, command injection, and malformed inputs.
func validateIdentifier(id string) bool {
	if len(id) == 0 || len(id) > 128 {
		return false
	}
	return identifierRegex.MatchString(id)
}

// ServerAPI bundles dependencies for all API endpoints.
type ServerAPI struct {
	metricsCollector metrics.Collector
	dockerClient     docker.Client
	servicesManager  *services.Manager
	hostCtrl         *hostctrl.Manager
	wsHub            *WSHub
	version          string
}

// NewServerAPI initializes the ServerAPI with required dependencies.
func NewServerAPI(
	collector metrics.Collector,
	dockerCli docker.Client,
	servicesMgr *services.Manager,
	hostCtrl *hostctrl.Manager,
	wsHub *WSHub,
	version string,
) *ServerAPI {
	if version == "" {
		version = "1.0.0"
	}
	if hostCtrl == nil {
		hostCtrl = hostctrl.NewManager(dockerCli.IsMock())
	}
	return &ServerAPI{
		metricsCollector: collector,
		dockerClient:     dockerCli,
		servicesManager:  servicesMgr,
		hostCtrl:         hostCtrl,
		wsHub:            wsHub,
		version:          version,
	}
}

// HealthCheckHandler handles GET /healthz (unauthenticated).
func (api *ServerAPI) HealthCheckHandler(w http.ResponseWriter, r *http.Request) {
	respondJSON(w, http.StatusOK, map[string]any{
		"status":  "ok",
		"version": api.version,
		"mock":    api.dockerClient.IsMock(),
	})
}

// HostHandler handles GET /api/v1/host.
func (api *ServerAPI) HostHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	summary, err := api.dockerClient.GetSummary(ctx)
	if err != nil {
		log.Printf("[API] Failed to get container summary: %v", err)
		summary = metrics.ContainersSummary{}
	}

	overview, err := api.metricsCollector.GetHostOverview(ctx, summary)
	if err != nil {
		respondError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to retrieve host overview: %v", err))
		return
	}

	respondJSON(w, http.StatusOK, overview)
}

// ContainersHandler handles GET /api/v1/containers.
func (api *ServerAPI) ContainersHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	containers, err := api.dockerClient.ListContainers(ctx)
	if err != nil {
		respondError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to list containers: %v", err))
		return
	}

	if containers == nil {
		containers = []docker.ContainerSummary{}
	}

	respondJSON(w, http.StatusOK, containers)
}

// ContainerStatsHandler handles GET /api/v1/containers/{id}/stats.
func (api *ServerAPI) ContainerStatsHandler(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !validateIdentifier(id) {
		respondError(w, http.StatusBadRequest, "Invalid or missing container ID")
		return
	}

	ctx := r.Context()
	stats, err := api.dockerClient.GetContainerStats(ctx, id)
	if err != nil {
		respondError(w, http.StatusNotFound, fmt.Sprintf("Failed to get container stats: %v", err))
		return
	}

	respondJSON(w, http.StatusOK, stats)
}

// ContainerLogsHandler handles GET /api/v1/containers/{id}/logs?tail=200&timestamps=true.
func (api *ServerAPI) ContainerLogsHandler(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !validateIdentifier(id) {
		respondError(w, http.StatusBadRequest, "Invalid or missing container ID")
		return
	}

	tail := 200
	if tailQuery := r.URL.Query().Get("tail"); tailQuery != "" {
		if parsed, err := strconv.Atoi(tailQuery); err == nil && parsed > 0 {
			tail = parsed
			if tail > 2000 {
				tail = 2000 // Prevent memory exhaustion DOS attack
			}
		}
	}

	timestamps := true
	if tsQuery := r.URL.Query().Get("timestamps"); tsQuery != "" {
		if parsed, err := strconv.ParseBool(tsQuery); err == nil {
			timestamps = parsed
		}
	}

	ctx := r.Context()
	logsResp, err := api.dockerClient.GetContainerLogs(ctx, id, tail, timestamps)
	if err != nil {
		respondError(w, http.StatusNotFound, fmt.Sprintf("Failed to get container logs: %v", err))
		return
	}

	if logsResp.Lines == nil {
		logsResp.Lines = []string{}
	}

	respondJSON(w, http.StatusOK, logsResp)
}

// ContainerStartHandler handles POST /api/v1/containers/{id}/start.
func (api *ServerAPI) ContainerStartHandler(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !validateIdentifier(id) {
		respondError(w, http.StatusBadRequest, "Invalid or missing container ID")
		return
	}

	ctx := r.Context()
	if err := api.dockerClient.StartContainer(ctx, id); err != nil {
		respondError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to start container: %v", err))
		return
	}

	api.wsHub.BroadcastContainerEvent(docker.ContainerEventData{
		ContainerID: id,
		Action:      "start",
		Status:      "running",
	})

	respondJSON(w, http.StatusOK, docker.ContainerActionResponse{
		Success: true,
		Message: "Container started successfully",
	})
}

// ContainerStopHandler handles POST /api/v1/containers/{id}/stop.
func (api *ServerAPI) ContainerStopHandler(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !validateIdentifier(id) {
		respondError(w, http.StatusBadRequest, "Invalid or missing container ID")
		return
	}

	ctx := r.Context()
	if err := api.dockerClient.StopContainer(ctx, id); err != nil {
		respondError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to stop container: %v", err))
		return
	}

	api.wsHub.BroadcastContainerEvent(docker.ContainerEventData{
		ContainerID: id,
		Action:      "stop",
		Status:      "exited",
	})

	respondJSON(w, http.StatusOK, docker.ContainerActionResponse{
		Success: true,
		Message: "Container stopped successfully",
	})
}

// ContainerRestartHandler handles POST /api/v1/containers/{id}/restart.
func (api *ServerAPI) ContainerRestartHandler(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !validateIdentifier(id) {
		respondError(w, http.StatusBadRequest, "Invalid or missing container ID")
		return
	}

	ctx := r.Context()
	if err := api.dockerClient.RestartContainer(ctx, id); err != nil {
		respondError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to restart container: %v", err))
		return
	}

	api.wsHub.BroadcastContainerEvent(docker.ContainerEventData{
		ContainerID: id,
		Action:      "restart",
		Status:      "running",
	})

	respondJSON(w, http.StatusOK, docker.ContainerActionResponse{
		Success: true,
		Message: "Container restarted successfully",
	})
}

// HostRebootHandler handles POST /api/v1/host/reboot.
func (api *ServerAPI) HostRebootHandler(w http.ResponseWriter, r *http.Request) {
	resp := api.hostCtrl.Reboot(3 * time.Second)
	respondJSON(w, http.StatusOK, resp)
}

// HostShutdownHandler handles POST /api/v1/host/shutdown.
func (api *ServerAPI) HostShutdownHandler(w http.ResponseWriter, r *http.Request) {
	resp := api.hostCtrl.Shutdown(3 * time.Second)
	respondJSON(w, http.StatusOK, resp)
}

// HostExecHandler handles POST /api/v1/host/exec (Terminal / Shell Commands).
func (api *ServerAPI) HostExecHandler(w http.ResponseWriter, r *http.Request) {
	var req hostctrl.ExecRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if strings.TrimSpace(req.Command) == "" {
		respondError(w, http.StatusBadRequest, "Empty command")
		return
	}

	ctx := r.Context()
	result, err := api.hostCtrl.ExecuteHostCommand(ctx, req.Command)
	if err != nil {
		respondError(w, http.StatusInternalServerError, fmt.Sprintf("Command execution error: %v", err))
		return
	}

	respondJSON(w, http.StatusOK, result)
}

// SystemPruneHandler handles POST /api/v1/system/prune (reclaims space).
func (api *ServerAPI) SystemPruneHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	report, err := api.dockerClient.Prune(ctx)
	if err != nil {
		respondError(w, http.StatusInternalServerError, fmt.Sprintf("Docker prune failed: %v", err))
		return
	}
	respondJSON(w, http.StatusOK, report)
}

// SystemRestartUnhealthyHandler handles POST /api/v1/system/restart-unhealthy.
func (api *ServerAPI) SystemRestartUnhealthyHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	restarted, err := api.dockerClient.RestartUnhealthy(ctx)
	if err != nil {
		respondError(w, http.StatusInternalServerError, fmt.Sprintf("Restart unhealthy failed: %v", err))
		return
	}
	respondJSON(w, http.StatusOK, map[string]any{
		"success":         true,
		"restarted_count": len(restarted),
		"containers":      restarted,
		"message":         fmt.Sprintf("Restarted %d unhealthy or exited containers", len(restarted)),
	})
}

// SystemDiagnosticsHandler handles GET /api/v1/system/diagnostics.
func (api *ServerAPI) SystemDiagnosticsHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	report, err := api.hostCtrl.GetDiagnostics(ctx)
	if err != nil {
		respondError(w, http.StatusInternalServerError, fmt.Sprintf("Diagnostics failed: %v", err))
		return
	}
	respondJSON(w, http.StatusOK, report)
}

// ServicesHandler handles GET /api/v1/services.
func (api *ServerAPI) ServicesHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var discovered []services.DiscoveredContainer
	if containers, err := api.dockerClient.ListContainers(ctx); err == nil {
		for _, c := range containers {
			discovered = append(discovered, services.DiscoveredContainer{
				Name:  c.Name,
				Image: c.Image,
				State: c.State,
				Ports: c.Ports,
			})
		}
	}

	statuses := api.servicesManager.ProbeAll(ctx, discovered...)
	if statuses == nil {
		statuses = []services.ServiceStatus{}
	}

	respondJSON(w, http.StatusOK, statuses)
}

// AddServiceHandler handles POST /api/v1/services.
func (api *ServerAPI) AddServiceHandler(w http.ResponseWriter, r *http.Request) {
	var req services.ServiceConfig
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	created, err := api.servicesManager.AddService(req)
	if err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	respondJSON(w, http.StatusCreated, created)
}

// DeleteServiceHandler handles DELETE /api/v1/services/{id}.
func (api *ServerAPI) DeleteServiceHandler(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !validateIdentifier(id) {
		respondError(w, http.StatusBadRequest, "Invalid or missing service ID")
		return
	}

	if err := api.servicesManager.DeleteService(id); err != nil {
		respondError(w, http.StatusNotFound, err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Service deleted successfully",
	})
}

// EventsWebSocketHandler handles GET /api/v1/events (WebSocket).
func (api *ServerAPI) EventsWebSocketHandler(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WebSocket] Upgrade error: %v", err)
		return
	}

	client := &WSClient{
		hub:  api.wsHub,
		conn: conn,
		send: make(chan []byte, 256),
	}
	client.hub.register <- client

	// Immediately push current host overview on connect safely
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		summary, _ := api.dockerClient.GetSummary(ctx)
		if overview, err := api.metricsCollector.GetHostOverview(ctx, summary); err == nil {
			client.hub.BroadcastHostTick(overview)
		}
	}()

	go client.writePump()
	go client.readPump()
}

// Helpers
func respondJSON(w http.ResponseWriter, statusCode int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(data)
}

func respondError(w http.ResponseWriter, statusCode int, message string) {
	respondJSON(w, statusCode, map[string]string{
		"error": message,
	})
}
