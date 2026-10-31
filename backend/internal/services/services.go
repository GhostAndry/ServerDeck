package services

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"gopkg.in/yaml.v3"
)

// ServiceConfig defines a configured service entry from YAML or dynamic addition.
type ServiceConfig struct {
	ID             string `yaml:"id" json:"id"`
	Name           string `yaml:"name" json:"name"`
	URL            string `yaml:"url" json:"url"`
	Icon           string `yaml:"icon" json:"icon"`
	Category       string `yaml:"category" json:"category"`
	AutoDiscovered bool   `yaml:"-" json:"auto_discovered,omitempty"`
}

// ServicesFile represents the structure of services.yml.
type ServicesFile struct {
	Services []ServiceConfig `yaml:"services"`
}

// ServiceStatus represents the health check result for a service.
type ServiceStatus struct {
	ID             string `json:"id"`
	Name           string `json:"name"`
	URL            string `json:"url"`
	Icon           string `json:"icon"`
	Category       string `json:"category"`
	Status         string `json:"status"` // "online", "degraded", "offline"
	ResponseTimeMs int64  `json:"response_time_ms"`
	StatusCode     int    `json:"status_code"`
	AutoDiscovered bool   `json:"auto_discovered,omitempty"`
}

// DiscoveredContainer represents container info for dynamic service discovery.
type DiscoveredContainer struct {
	Name  string
	Image string
	State string
	Ports []string
}

// Manager loads services from YAML, probes their status, and supports dynamic discovery.
type Manager struct {
	mu         sync.RWMutex
	configPath string
	services   []ServiceConfig
	httpClient *http.Client
}

// NewManager creates a new services Manager.
func NewManager(configPath string) *Manager {
	// Homelab services frequently use self-signed TLS certificates
	tr := &http.Transport{
		TLSClientConfig:   &tls.Config{InsecureSkipVerify: true},
		DisableKeepAlives: true,
	}

	return &Manager{
		configPath: configPath,
		httpClient: &http.Client{
			Transport: tr,
			Timeout:   2500 * time.Millisecond,
		},
	}
}

// Load reads services from the YAML config file, or creates default services if missing.
func (m *Manager) Load() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	data, err := os.ReadFile(m.configPath)
	if err != nil {
		if os.IsNotExist(err) {
			log.Printf("[Services] Config file not found at %s, loading defaults.", m.configPath)
			m.services = defaultServices()
			return nil
		}
		return fmt.Errorf("read services config: %w", err)
	}

	var sf ServicesFile
	if err := yaml.Unmarshal(data, &sf); err != nil {
		return fmt.Errorf("parse services config yaml: %w", err)
	}

	if len(sf.Services) == 0 {
		m.services = defaultServices()
	} else {
		m.services = sf.Services
	}

	log.Printf("[Services] Loaded %d configured services from %s", len(m.services), m.configPath)
	return nil
}

// Save writes the configured services back to the YAML file.
func (m *Manager) Save() error {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.saveLocked()
}

func (m *Manager) saveLocked() error {
	// Filter out auto-discovered services so we only persist user-configured ones
	persistable := make([]ServiceConfig, 0, len(m.services))
	for _, s := range m.services {
		if !s.AutoDiscovered {
			persistable = append(persistable, s)
		}
	}

	sf := ServicesFile{Services: persistable}
	data, err := yaml.Marshal(&sf)
	if err != nil {
		return fmt.Errorf("marshal services yaml: %w", err)
	}

	if err := os.MkdirAll(filepath.Dir(m.configPath), 0755); err != nil {
		log.Printf("[Services] Warning: could not create directory for config: %v", err)
	}

	if err := os.WriteFile(m.configPath, data, 0644); err != nil {
		log.Printf("[Services] Warning: failed to save config file (%v). Changes kept in memory.", err)
		return nil
	}

	log.Printf("[Services] Successfully saved %d services to %s", len(persistable), m.configPath)
	return nil
}

// AddService dynamically adds a new service and persists it.
func (m *Manager) AddService(svc ServiceConfig) (*ServiceConfig, error) {
	if strings.TrimSpace(svc.Name) == "" {
		return nil, errors.New("service name is required")
	}
	if strings.TrimSpace(svc.URL) == "" {
		return nil, errors.New("service URL is required")
	}

	// Normalize URL
	if !strings.HasPrefix(svc.URL, "http://") && !strings.HasPrefix(svc.URL, "https://") {
		svc.URL = "http://" + svc.URL
	}

	// Security: Prevent SSRF targeting cloud metadata services
	lowerURL := strings.ToLower(svc.URL)
	if strings.Contains(lowerURL, "169.254.169.254") || strings.Contains(lowerURL, "metadata.google.internal") {
		return nil, errors.New("invalid service URL: target address is restricted")
	}

	// Generate ID if missing
	if strings.TrimSpace(svc.ID) == "" {
		reg := regexp.MustCompile("[^a-zA-Z0-9_-]+")
		svc.ID = strings.ToLower(reg.ReplaceAllString(svc.Name, "-"))
	}

	// Default icon & category
	if svc.Icon == "" {
		svc.Icon = "app.fill"
	}
	if svc.Category == "" {
		svc.Category = "Custom"
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	// Update existing if ID already exists, or append
	updated := false
	for i, existing := range m.services {
		if existing.ID == svc.ID {
			m.services[i] = svc
			updated = true
			break
		}
	}
	if !updated {
		m.services = append(m.services, svc)
	}

	_ = m.saveLocked()
	return &svc, nil
}

// DeleteService removes a service by ID and persists changes.
func (m *Manager) DeleteService(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	found := false
	filtered := make([]ServiceConfig, 0, len(m.services))
	for _, s := range m.services {
		if s.ID == id {
			found = true
			continue
		}
		filtered = append(filtered, s)
	}

	if !found {
		return fmt.Errorf("service with ID '%s' not found", id)
	}

	m.services = filtered
	_ = m.saveLocked()
	return nil
}

// GetServices returns the current list of configured services.
func (m *Manager) GetServices() []ServiceConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	res := make([]ServiceConfig, len(m.services))
	copy(res, m.services)
	return res
}

// SetServices overrides the current list of services (useful for testing).
func (m *Manager) SetServices(services []ServiceConfig) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.services = services
}

// ProbeAll concurrently probes all configured and optionally auto-discovered services.
func (m *Manager) ProbeAll(ctx context.Context, discoveredContainers ...DiscoveredContainer) []ServiceStatus {
	m.mu.RLock()
	svcs := make([]ServiceConfig, len(m.services))
	copy(svcs, m.services)
	m.mu.RUnlock()

	// Merge dynamically discovered services from running containers
	knownIDs := make(map[string]bool)
	knownURLs := make(map[string]bool)
	for _, s := range svcs {
		knownIDs[strings.ToLower(s.ID)] = true
		knownURLs[strings.ToLower(strings.TrimRight(s.URL, "/"))] = true
	}

	hostname := os.Getenv("SERVERDECK_HOSTNAME")
	if hostname == "" {
		hostname = "srv-01"
	}

	for _, c := range discoveredContainers {
		if c.State != "running" && c.State != "Up" && !strings.Contains(strings.ToLower(c.State), "up") {
			continue
		}
		// Skip self
		if strings.Contains(c.Name, "serverdeck") {
			continue
		}

		// Find public mapped ports
		for _, p := range c.Ports {
			publicPort := extractPublicPort(p)
			if publicPort <= 0 {
				continue
			}

			// Check if likely a web service (skip internal database ports if unneeded, or include them)
			isWeb := isLikelyWebService(publicPort, c.Name, c.Image)
			if !isWeb {
				continue
			}

			scheme := "http"
			if publicPort == 443 || publicPort == 9443 || strings.Contains(strings.ToLower(c.Name), "portainer") {
				scheme = "https"
			}

			url := fmt.Sprintf("%s://%s:%d", scheme, hostname, publicPort)
			id := sanitizeID(c.Name)

			if knownIDs[id] || knownURLs[strings.ToLower(url)] {
				continue
			}

			category, icon := inferCategoryAndIcon(c.Name, c.Image, publicPort)

			discoveredSvc := ServiceConfig{
				ID:             id,
				Name:           formatServiceName(c.Name),
				URL:            url,
				Icon:           icon,
				Category:       category,
				AutoDiscovered: true,
			}

			knownIDs[id] = true
			knownURLs[strings.ToLower(url)] = true
			svcs = append(svcs, discoveredSvc)
		}
	}

	results := make([]ServiceStatus, len(svcs))
	var wg sync.WaitGroup

	for i, svc := range svcs {
		wg.Add(1)
		go func(idx int, s ServiceConfig) {
			defer wg.Done()
			results[idx] = m.probeService(ctx, s)
		}(i, svc)
	}

	wg.Wait()
	return results
}

func (m *Manager) probeService(ctx context.Context, svc ServiceConfig) ServiceStatus {
	status := ServiceStatus{
		ID:             svc.ID,
		Name:           svc.Name,
		URL:            svc.URL,
		Icon:           svc.Icon,
		Category:       svc.Category,
		Status:         "offline",
		ResponseTimeMs: 0,
		StatusCode:     0,
		AutoDiscovered: svc.AutoDiscovered,
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, svc.URL, nil)
	if err != nil {
		return status
	}

	start := time.Now()
	resp, err := m.httpClient.Do(req)
	duration := time.Since(start).Milliseconds()
	if duration <= 0 {
		duration = 1
	}

	if err != nil {
		// Attempt fallback HEAD request if GET failed
		reqHead, errHead := http.NewRequestWithContext(ctx, http.MethodHead, svc.URL, nil)
		if errHead == nil {
			startHead := time.Now()
			if respHead, errDoHead := m.httpClient.Do(reqHead); errDoHead == nil {
				durationHead := time.Since(startHead).Milliseconds()
				if durationHead <= 0 {
					durationHead = 1
				}
				defer respHead.Body.Close()
				return evaluateResponse(svc, respHead.StatusCode, durationHead)
			}
		}

		status.Status = "offline"
		return status
	}
	defer resp.Body.Close()

	return evaluateResponse(svc, resp.StatusCode, duration)
}

func evaluateResponse(svc ServiceConfig, statusCode int, durationMs int64) ServiceStatus {
	res := ServiceStatus{
		ID:             svc.ID,
		Name:           svc.Name,
		URL:            svc.URL,
		Icon:           svc.Icon,
		Category:       svc.Category,
		ResponseTimeMs: durationMs,
		StatusCode:     statusCode,
		AutoDiscovered: svc.AutoDiscovered,
	}

	switch {
	case statusCode >= 200 && statusCode < 400:
		res.Status = "online"
	case statusCode >= 400 && statusCode < 500:
		// 4xx (e.g. 401 Unauthorized, 403 Forbidden) indicates the service is running and serving HTTP
		res.Status = "online"
	case statusCode >= 500:
		// 5xx indicates server error / degraded service
		res.Status = "degraded"
	default:
		res.Status = "offline"
	}

	return res
}

func defaultServices() []ServiceConfig {
	return []ServiceConfig{
		{
			ID:       "portainer",
			Name:     "Portainer",
			URL:      "https://srv-01:9443",
			Icon:     "shippingbox.fill",
			Category: "Management",
		},
		{
			ID:       "beszel",
			Name:     "Beszel",
			URL:      "http://srv-01:8090",
			Icon:     "chart.xyaxis.line",
			Category: "Monitoring",
		},
		{
			ID:       "license-manager",
			Name:     "License Manager",
			URL:      "http://srv-01:3001",
			Icon:     "key.fill",
			Category: "Apps",
		},
	}
}

// Helpers for auto-discovery
func extractPublicPort(portStr string) int {
	// Examples: "8090:8090", "0.0.0.0:8090->8090/tcp", "80/tcp"
	if strings.Contains(portStr, "->") {
		parts := strings.Split(portStr, "->")
		left := parts[0]
		sub := strings.Split(left, ":")
		p, err := strconv.Atoi(sub[len(sub)-1])
		if err == nil {
			return p
		}
	} else if strings.Contains(portStr, ":") {
		parts := strings.Split(portStr, ":")
		p, err := strconv.Atoi(parts[0])
		if err == nil {
			return p
		}
	}
	return 0
}

func isLikelyWebService(port int, name, image string) bool {
	lower := strings.ToLower(name + " " + image)
	if strings.Contains(lower, "postgres") || strings.Contains(lower, "mongo") ||
		strings.Contains(lower, "redis") || strings.Contains(lower, "mariadb") ||
		strings.Contains(lower, "mysql") || strings.Contains(lower, "mssql") {
		// Pure database ports are typically not HTTP web UIs unless port is a web admin
		return false
	}
	// Common web ports: 80, 81, 443, 3000-3999, 5000-5999, 7000-9999
	if port == 80 || port == 81 || port == 443 || port == 8000 || port == 8080 || port == 8090 ||
		port == 9443 || port == 9000 || (port >= 3000 && port <= 3999) || (port >= 5000 && port <= 5999) ||
		(port >= 7000 && port <= 9999) {
		return true
	}
	return false
}

func inferCategoryAndIcon(name, image string, port int) (string, string) {
	lower := strings.ToLower(name + " " + image)
	switch {
	case strings.Contains(lower, "portainer"):
		return "Management", "shippingbox.fill"
	case strings.Contains(lower, "beszel") || strings.Contains(lower, "monitor") || strings.Contains(lower, "grafana"):
		return "Monitoring", "chart.xyaxis.line"
	case strings.Contains(lower, "nginx") || strings.Contains(lower, "caddy") || strings.Contains(lower, "traefik") || strings.Contains(lower, "proxy"):
		return "Proxy", "network"
	case strings.Contains(lower, "torrent") || strings.Contains(lower, "plex") || strings.Contains(lower, "jellyfin") || strings.Contains(lower, "media"):
		return "Media", "play.tv.fill"
	case strings.Contains(lower, "bot") || strings.Contains(lower, "discord"):
		return "Bot", "bubble.left.and.bubble.right.fill"
	case strings.Contains(lower, "license"):
		return "Apps", "key.fill"
	default:
		return "Services", "app.fill"
	}
}

func formatServiceName(raw string) string {
	raw = strings.TrimPrefix(raw, "/")
	raw = strings.ReplaceAll(raw, "_", " ")
	raw = strings.ReplaceAll(raw, "-", " ")
	words := strings.Fields(raw)
	for i, w := range words {
		if len(w) > 0 {
			words[i] = strings.ToUpper(w[:1]) + strings.ToLower(w[1:])
		}
	}
	return strings.Join(words, " ")
}

func sanitizeID(name string) string {
	name = strings.TrimPrefix(name, "/")
	reg := regexp.MustCompile("[^a-zA-Z0-9_-]+")
	return strings.ToLower(reg.ReplaceAllString(name, "-"))
}
