package config

import (
	"os"
	"strconv"
	"time"
)

// Config holds all configuration parameters for the ServerDeck backend agent.
type Config struct {
	// ListenAddr is the network address the HTTP server listens on (e.g. "0.0.0.0:8080").
	ListenAddr string

	// AuthToken is the secret token required for authentication via Bearer or X-API-Key.
	AuthToken string

	// ServicesConfigPath is the path to the YAML file declaring monitored services.
	ServicesConfigPath string

	// DatabasePath is the path to the SQLite database (if used for history).
	DatabasePath string

	// HostProc is the host /proc mount path (e.g. "/host/proc" when containerized).
	HostProc string

	// HostSys is the host /sys mount path (e.g. "/host/sys" when containerized).
	HostSys string

	// ForceMockDocker forces mock Docker mode without attempting to connect to dockerd.
	ForceMockDocker bool

	// ForceMockMetrics forces mock metrics collection.
	ForceMockMetrics bool

	// TickInterval is the duration between real-time host_tick broadcasts over WebSocket.
	TickInterval time.Duration

	// AllowedOrigins is the comma-separated or wildcard CORS allowed origins.
	AllowedOrigins string
}

// Default values
const (
	DefaultListenAddr         = "0.0.0.0:8080"
	DefaultAuthToken          = "serverdeck-dev-secret-token"
	DefaultServicesConfigPath = "config/services.yml"
	DefaultDatabasePath       = "data/serverdeck.db"
	DefaultTickInterval       = 2 * time.Second
	DefaultAllowedOrigins     = "*"
)

// Load reads configuration from environment variables and applies sensible defaults.
func Load() *Config {
	cfg := &Config{
		ListenAddr:         getEnv("SERVERDECK_LISTEN", DefaultListenAddr),
		AuthToken:          getEnv("SERVERDECK_TOKEN", DefaultAuthToken),
		ServicesConfigPath: getEnv("SERVERDECK_CONFIG", DefaultServicesConfigPath),
		DatabasePath:       getEnv("SERVERDECK_DB", DefaultDatabasePath),
		HostProc:           getEnv("HOST_PROC", ""),
		HostSys:            getEnv("HOST_SYS", ""),
		ForceMockDocker:    getEnvBool("SERVERDECK_MOCK_DOCKER", false),
		ForceMockMetrics:   getEnvBool("SERVERDECK_MOCK_METRICS", false),
		TickInterval:       getEnvDuration("SERVERDECK_TICK_INTERVAL_SEC", DefaultTickInterval),
		AllowedOrigins:     getEnv("SERVERDECK_CORS_ALLOWED_ORIGINS", DefaultAllowedOrigins),
	}

	// Propagate HOST_PROC and HOST_SYS to environment for gopsutil if set
	if cfg.HostProc != "" {
		_ = os.Setenv("HOST_PROC", cfg.HostProc)
	}
	if cfg.HostSys != "" {
		_ = os.Setenv("HOST_SYS", cfg.HostSys)
	}

	return cfg
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func getEnvBool(key string, defaultVal bool) bool {
	val := os.Getenv(key)
	if val == "" {
		return defaultVal
	}
	b, err := strconv.ParseBool(val)
	if err != nil {
		return defaultVal
	}
	return b
}

func getEnvDuration(key string, defaultVal time.Duration) time.Duration {
	val := os.Getenv(key)
	if val == "" {
		return defaultVal
	}
	sec, err := strconv.Atoi(val)
	if err != nil || sec <= 0 {
		return defaultVal
	}
	return time.Duration(sec) * time.Second
}
