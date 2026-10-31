package config

import (
	"os"
	"testing"
	"time"
)

func TestConfigDefaults(t *testing.T) {
	// Clear any env vars
	os.Unsetenv("SERVERDECK_LISTEN")
	os.Unsetenv("SERVERDECK_TOKEN")
	os.Unsetenv("SERVERDECK_CONFIG")
	os.Unsetenv("SERVERDECK_DB")
	os.Unsetenv("SERVERDECK_MOCK_DOCKER")
	os.Unsetenv("SERVERDECK_TICK_INTERVAL_SEC")

	cfg := Load()

	if cfg.ListenAddr != DefaultListenAddr {
		t.Errorf("expected ListenAddr %s, got %s", DefaultListenAddr, cfg.ListenAddr)
	}
	if cfg.AuthToken != DefaultAuthToken {
		t.Errorf("expected AuthToken %s, got %s", DefaultAuthToken, cfg.AuthToken)
	}
	if cfg.ServicesConfigPath != DefaultServicesConfigPath {
		t.Errorf("expected ServicesConfigPath %s, got %s", DefaultServicesConfigPath, cfg.ServicesConfigPath)
	}
	if cfg.ForceMockDocker != false {
		t.Errorf("expected ForceMockDocker false, got %v", cfg.ForceMockDocker)
	}
	if cfg.TickInterval != DefaultTickInterval {
		t.Errorf("expected TickInterval %v, got %v", DefaultTickInterval, cfg.TickInterval)
	}
}

func TestConfigEnvOverrides(t *testing.T) {
	t.Setenv("SERVERDECK_LISTEN", "127.0.0.1:9090")
	t.Setenv("SERVERDECK_TOKEN", "custom-secret-123")
	t.Setenv("SERVERDECK_CONFIG", "/custom/services.yml")
	t.Setenv("SERVERDECK_DB", "/custom/db.sqlite")
	t.Setenv("SERVERDECK_MOCK_DOCKER", "true")
	t.Setenv("SERVERDECK_TICK_INTERVAL_SEC", "5")
	t.Setenv("HOST_PROC", "/host/proc")
	t.Setenv("HOST_SYS", "/host/sys")

	cfg := Load()

	if cfg.ListenAddr != "127.0.0.1:9090" {
		t.Errorf("expected ListenAddr 127.0.0.1:9090, got %s", cfg.ListenAddr)
	}
	if cfg.AuthToken != "custom-secret-123" {
		t.Errorf("expected AuthToken custom-secret-123, got %s", cfg.AuthToken)
	}
	if cfg.ServicesConfigPath != "/custom/services.yml" {
		t.Errorf("expected ServicesConfigPath /custom/services.yml, got %s", cfg.ServicesConfigPath)
	}
	if cfg.DatabasePath != "/custom/db.sqlite" {
		t.Errorf("expected DatabasePath /custom/db.sqlite, got %s", cfg.DatabasePath)
	}
	if cfg.ForceMockDocker != true {
		t.Errorf("expected ForceMockDocker true, got %v", cfg.ForceMockDocker)
	}
	if cfg.TickInterval != 5*time.Second {
		t.Errorf("expected TickInterval 5s, got %v", cfg.TickInterval)
	}
	if cfg.HostProc != "/host/proc" {
		t.Errorf("expected HostProc /host/proc, got %s", cfg.HostProc)
	}
	if cfg.HostSys != "/host/sys" {
		t.Errorf("expected HostSys /host/sys, got %s", cfg.HostSys)
	}
}
