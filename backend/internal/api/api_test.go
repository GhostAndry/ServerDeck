package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/serverdeck/serverdeck-backend/internal/auth"
	"github.com/serverdeck/serverdeck-backend/internal/docker"
	"github.com/serverdeck/serverdeck-backend/internal/hostctrl"
	"github.com/serverdeck/serverdeck-backend/internal/metrics"
	"github.com/serverdeck/serverdeck-backend/internal/services"
)

func setupTestServer(t *testing.T) (http.Handler, string, *WSHub) {
	secret := "test-token-xyz"
	authMw := auth.NewMiddleware(secret, "*")

	collector := metrics.NewMockCollector()
	dockerCli := docker.NewMockClient()
	svcMgr := services.NewManager("nonexistent.yml")
	_ = svcMgr.Load()

	hub := NewWSHub()
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go hub.Run(ctx)

	hostCtrl := hostctrl.NewManager(true)
	api := NewServerAPI(collector, dockerCli, svcMgr, hostCtrl, hub, "1.0.0-test")
	handler := SetupRouter(api, authMw)

	return handler, secret, hub
}

func TestHealthCheck(t *testing.T) {
	handler, _, _ := setupTestServer(t)

	req := httptest.NewRequest("GET", "/healthz", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rr.Code)
	}

	var resp map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse json: %v", err)
	}
	if resp["status"] != "ok" {
		t.Errorf("expected status 'ok', got '%v'", resp["status"])
	}
}

func TestHostEndpoint(t *testing.T) {
	handler, secret, _ := setupTestServer(t)

	// Without token -> 401
	reqUnauth := httptest.NewRequest("GET", "/api/v1/host", nil)
	rrUnauth := httptest.NewRecorder()
	handler.ServeHTTP(rrUnauth, reqUnauth)
	if rrUnauth.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rrUnauth.Code)
	}

	// With token -> 200
	reqAuth := httptest.NewRequest("GET", "/api/v1/host", nil)
	reqAuth.Header.Set("Authorization", "Bearer "+secret)
	rrAuth := httptest.NewRecorder()
	handler.ServeHTTP(rrAuth, reqAuth)

	if rrAuth.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rrAuth.Code)
	}

	var overview metrics.HostOverview
	if err := json.Unmarshal(rrAuth.Body.Bytes(), &overview); err != nil {
		t.Fatalf("failed to decode host overview: %v", err)
	}
	if overview.Hostname != "srv-01" {
		t.Errorf("expected hostname 'srv-01', got '%s'", overview.Hostname)
	}
	if len(overview.Disks) < 2 {
		t.Errorf("expected at least 2 disks, got %d", len(overview.Disks))
	}
}

func TestContainersEndpoints(t *testing.T) {
	handler, secret, _ := setupTestServer(t)

	// 1. List containers
	reqList := httptest.NewRequest("GET", "/api/v1/containers", nil)
	reqList.Header.Set("Authorization", "Bearer "+secret)
	rrList := httptest.NewRecorder()
	handler.ServeHTTP(rrList, reqList)

	if rrList.Code != http.StatusOK {
		t.Fatalf("expected 200 for containers list, got %d", rrList.Code)
	}

	var containers []docker.ContainerSummary
	if err := json.Unmarshal(rrList.Body.Bytes(), &containers); err != nil {
		t.Fatalf("failed to parse containers: %v", err)
	}
	if len(containers) < 4 {
		t.Errorf("expected at least 4 containers, got %d", len(containers))
	}

	cid := containers[0].ID

	// 2. Container stats
	reqStats := httptest.NewRequest("GET", "/api/v1/containers/"+cid+"/stats", nil)
	reqStats.Header.Set("Authorization", "Bearer "+secret)
	rrStats := httptest.NewRecorder()
	handler.ServeHTTP(rrStats, reqStats)

	if rrStats.Code != http.StatusOK {
		t.Fatalf("expected 200 for stats, got %d", rrStats.Code)
	}
	var stats docker.ContainerStats
	if err := json.Unmarshal(rrStats.Body.Bytes(), &stats); err != nil {
		t.Fatalf("failed to parse stats: %v", err)
	}
	if stats.ID != cid {
		t.Errorf("expected stats container ID %s, got %s", cid, stats.ID)
	}

	// 3. Container logs
	reqLogs := httptest.NewRequest("GET", "/api/v1/containers/"+cid+"/logs?tail=50&timestamps=true", nil)
	reqLogs.Header.Set("Authorization", "Bearer "+secret)
	rrLogs := httptest.NewRecorder()
	handler.ServeHTTP(rrLogs, reqLogs)

	if rrLogs.Code != http.StatusOK {
		t.Fatalf("expected 200 for logs, got %d", rrLogs.Code)
	}
	var logsResp docker.ContainerLogsResponse
	if err := json.Unmarshal(rrLogs.Body.Bytes(), &logsResp); err != nil {
		t.Fatalf("failed to parse logs: %v", err)
	}
	if logsResp.ContainerID != cid {
		t.Errorf("expected logs container ID %s, got %s", cid, logsResp.ContainerID)
	}

	// 4. Container restart action
	reqRestart := httptest.NewRequest("POST", "/api/v1/containers/"+cid+"/restart", nil)
	reqRestart.Header.Set("Authorization", "Bearer "+secret)
	rrRestart := httptest.NewRecorder()
	handler.ServeHTTP(rrRestart, reqRestart)

	if rrRestart.Code != http.StatusOK {
		t.Fatalf("expected 200 for restart, got %d", rrRestart.Code)
	}
	var actResp docker.ContainerActionResponse
	if err := json.Unmarshal(rrRestart.Body.Bytes(), &actResp); err != nil {
		t.Fatalf("failed to parse action response: %v", err)
	}
	if !actResp.Success {
		t.Errorf("expected success true in action response")
	}

	// 5. Container stop action
	reqStop := httptest.NewRequest("POST", "/api/v1/containers/"+cid+"/stop", nil)
	reqStop.Header.Set("Authorization", "Bearer "+secret)
	rrStop := httptest.NewRecorder()
	handler.ServeHTTP(rrStop, reqStop)
	if rrStop.Code != http.StatusOK {
		t.Fatalf("expected 200 for stop, got %d", rrStop.Code)
	}

	// 6. Container start action
	reqStart := httptest.NewRequest("POST", "/api/v1/containers/"+cid+"/start", nil)
	reqStart.Header.Set("Authorization", "Bearer "+secret)
	rrStart := httptest.NewRecorder()
	handler.ServeHTTP(rrStart, reqStart)
	if rrStart.Code != http.StatusOK {
		t.Fatalf("expected 200 for start, got %d", rrStart.Code)
	}
}

func TestServicesEndpoint(t *testing.T) {
	handler, secret, _ := setupTestServer(t)

	req := httptest.NewRequest("GET", "/api/v1/services", nil)
	req.Header.Set("Authorization", "Bearer "+secret)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 for services, got %d", rr.Code)
	}

	var statuses []services.ServiceStatus
	if err := json.Unmarshal(rr.Body.Bytes(), &statuses); err != nil {
		t.Fatalf("failed to parse service statuses: %v", err)
	}
	if len(statuses) == 0 {
		t.Errorf("expected non-empty services list")
	}
}

func TestWebSocketEvents(t *testing.T) {
	handler, secret, hub := setupTestServer(t)
	server := httptest.NewServer(handler)
	defer server.Close()

	// Convert http url to ws url
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/api/v1/events?token=" + secret

	conn, resp, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("failed to dial websocket: %v (status: %v)", err, resp)
	}
	defer conn.Close()

	// Broadcast container event and check receipt
	testEvent := docker.ContainerEventData{
		ContainerID: "test-c1",
		Action:      "restart",
		Status:      "running",
	}
	hub.BroadcastContainerEvent(testEvent)

	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, msgBytes, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("failed to read websocket message: %v", err)
	}

	var wsMsg WebSocketMessage
	if err := json.Unmarshal(msgBytes, &wsMsg); err != nil {
		t.Fatalf("failed to unmarshal ws message: %v", err)
	}

	if wsMsg.Type != "host_tick" && wsMsg.Type != "container_event" {
		t.Errorf("unexpected websocket event type: %s", wsMsg.Type)
	}
}

func TestHostControlAndPruneEndpoints(t *testing.T) {
	handler, secret, _ := setupTestServer(t)

	// 1. Test Host Reboot
	reqReboot := httptest.NewRequest("POST", "/api/v1/host/reboot", nil)
	reqReboot.Header.Set("Authorization", "Bearer "+secret)
	rrReboot := httptest.NewRecorder()
	handler.ServeHTTP(rrReboot, reqReboot)
	if rrReboot.Code != http.StatusOK {
		t.Fatalf("expected 200 for host reboot, got %d", rrReboot.Code)
	}

	// 2. Test Host Shutdown
	reqShutdown := httptest.NewRequest("POST", "/api/v1/host/shutdown", nil)
	reqShutdown.Header.Set("Authorization", "Bearer "+secret)
	rrShutdown := httptest.NewRecorder()
	handler.ServeHTTP(rrShutdown, reqShutdown)
	if rrShutdown.Code != http.StatusOK {
		t.Fatalf("expected 200 for host shutdown, got %d", rrShutdown.Code)
	}

	// 3. Test Docker Prune
	reqPrune := httptest.NewRequest("POST", "/api/v1/system/prune", nil)
	reqPrune.Header.Set("Authorization", "Bearer "+secret)
	rrPrune := httptest.NewRecorder()
	handler.ServeHTTP(rrPrune, reqPrune)
	if rrPrune.Code != http.StatusOK {
		t.Fatalf("expected 200 for docker prune, got %d", rrPrune.Code)
	}

	// 4. Test Restart Unhealthy
	reqRestart := httptest.NewRequest("POST", "/api/v1/system/restart-unhealthy", nil)
	reqRestart.Header.Set("Authorization", "Bearer "+secret)
	rrRestart := httptest.NewRecorder()
	handler.ServeHTTP(rrRestart, reqRestart)
	if rrRestart.Code != http.StatusOK {
		t.Fatalf("expected 200 for restart unhealthy, got %d", rrRestart.Code)
	}

	// 5. Test System Diagnostics
	reqDiag := httptest.NewRequest("GET", "/api/v1/system/diagnostics", nil)
	reqDiag.Header.Set("Authorization", "Bearer "+secret)
	rrDiag := httptest.NewRecorder()
	handler.ServeHTTP(rrDiag, reqDiag)
	if rrDiag.Code != http.StatusOK {
		t.Fatalf("expected 200 for system diagnostics, got %d", rrDiag.Code)
	}
}

func TestSecurityInputValidation(t *testing.T) {
	handler, secret, _ := setupTestServer(t)

	// 1. Path traversal / malicious container ID
	reqBadID := httptest.NewRequest("GET", "/api/v1/containers/../../etc/passwd/stats", nil)
	reqBadID.Header.Set("Authorization", "Bearer "+secret)
	rrBadID := httptest.NewRecorder()
	handler.ServeHTTP(rrBadID, reqBadID)
	if rrBadID.Code == http.StatusOK {
		t.Errorf("expected rejection for path traversal ID, got %d", rrBadID.Code)
	}

	// 2. Excessive log tail cap check
	reqLogs := httptest.NewRequest("GET", "/api/v1/containers/c1a2b3c4d5e6/logs?tail=999999", nil)
	reqLogs.Header.Set("Authorization", "Bearer "+secret)
	rrLogs := httptest.NewRecorder()
	handler.ServeHTTP(rrLogs, reqLogs)
	if rrLogs.Code != http.StatusOK {
		t.Fatalf("expected 200 for logs, got %d", rrLogs.Code)
	}
}
