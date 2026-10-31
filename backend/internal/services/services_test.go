package services

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestServicesLoadAndProbe(t *testing.T) {
	// Create mock test HTTP servers
	ts200 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))
	defer ts200.Close()

	ts401 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte("unauthorized"))
	}))
	defer ts401.Close()

	ts500 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte("server error"))
	}))
	defer ts500.Close()

	// Write temp services.yml
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "services.yml")
	yamlContent := `services:
  - id: test-online
    name: Test Online
    url: ` + ts200.URL + `
    icon: checkmark
    category: Test
  - id: test-auth
    name: Test Auth
    url: ` + ts401.URL + `
    icon: lock
    category: Test
  - id: test-degraded
    name: Test Degraded
    url: ` + ts500.URL + `
    icon: exclamationmark
    category: Test
  - id: test-offline
    name: Test Offline
    url: http://127.0.0.1:59999
    icon: xmark
    category: Test
`
	if err := os.WriteFile(configPath, []byte(yamlContent), 0644); err != nil {
		t.Fatalf("failed to write temp services.yml: %v", err)
	}

	mgr := NewManager(configPath)
	if err := mgr.Load(); err != nil {
		t.Fatalf("failed to load services: %v", err)
	}

	svcs := mgr.GetServices()
	if len(svcs) != 4 {
		t.Fatalf("expected 4 services, got %d", len(svcs))
	}

	ctx := context.Background()
	results := mgr.ProbeAll(ctx)
	if len(results) != 4 {
		t.Fatalf("expected 4 probe results, got %d", len(results))
	}

	resultMap := make(map[string]ServiceStatus)
	for _, r := range results {
		resultMap[r.ID] = r
	}

	// 1. ts200 should be online
	if s, ok := resultMap["test-online"]; !ok || s.Status != "online" || s.StatusCode != 200 {
		t.Errorf("expected test-online to be online with 200, got status=%s code=%d", s.Status, s.StatusCode)
	}

	// 2. ts401 should be online (server is responding)
	if s, ok := resultMap["test-auth"]; !ok || s.Status != "online" || s.StatusCode != 401 {
		t.Errorf("expected test-auth to be online with 401, got status=%s code=%d", s.Status, s.StatusCode)
	}

	// 3. ts500 should be degraded
	if s, ok := resultMap["test-degraded"]; !ok || s.Status != "degraded" || s.StatusCode != 500 {
		t.Errorf("expected test-degraded to be degraded with 500, got status=%s code=%d", s.Status, s.StatusCode)
	}

	// 4. offline port should be offline
	if s, ok := resultMap["test-offline"]; !ok || s.Status != "offline" || s.StatusCode != 0 {
		t.Errorf("expected test-offline to be offline with 0, got status=%s code=%d", s.Status, s.StatusCode)
	}
}

func TestServicesDefaultFallback(t *testing.T) {
	mgr := NewManager("/non/existent/path/services.yml")
	if err := mgr.Load(); err != nil {
		t.Fatalf("expected fallback to default services without error, got %v", err)
	}
	if len(mgr.GetServices()) == 0 {
		t.Errorf("expected default services to be loaded")
	}
}

func TestServicesAddDeleteAndAutoDiscovery(t *testing.T) {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "services.yml")

	mgr := NewManager(configPath)
	_ = mgr.Load()

	// 1. Add service dynamically
	svc, err := mgr.AddService(ServiceConfig{
		Name:     "Custom Grafana",
		URL:      "http://srv-01:3000",
		Category: "Monitoring",
	})
	if err != nil {
		t.Fatalf("failed to add service: %v", err)
	}
	if svc.ID != "custom-grafana" {
		t.Errorf("expected generated id 'custom-grafana', got '%s'", svc.ID)
	}

	// Verify persistence in YAML
	loadedMgr := NewManager(configPath)
	if err := loadedMgr.Load(); err != nil {
		t.Fatalf("failed to reload persisted config: %v", err)
	}
	found := false
	for _, s := range loadedMgr.GetServices() {
		if s.ID == "custom-grafana" {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("expected added service to be persisted to yaml")
	}

	// 2. Test auto-discovery with running containers
	containers := []DiscoveredContainer{
		{
			Name:  "sonarr",
			Image: "linuxserver/sonarr",
			State: "running",
			Ports: []string{"8989:8989"},
		},
		{
			Name:  "postgres-db",
			Image: "postgres:16",
			State: "running",
			Ports: []string{"5432:5432"}, // Should not be auto-discovered as a web service
		},
	}

	probed := mgr.ProbeAll(context.Background(), containers...)
	foundDiscovered := false
	for _, p := range probed {
		if p.ID == "sonarr" {
			foundDiscovered = true
			if !p.AutoDiscovered {
				t.Errorf("expected auto_discovered to be true")
			}
			break
		}
	}
	if !foundDiscovered {
		t.Errorf("expected sonarr to be auto-discovered from containers")
	}

	// 3. Delete service dynamically
	if err := mgr.DeleteService("custom-grafana"); err != nil {
		t.Fatalf("failed to delete service: %v", err)
	}
	for _, s := range mgr.GetServices() {
		if s.ID == "custom-grafana" {
			t.Errorf("expected service to be deleted")
		}
	}
}
