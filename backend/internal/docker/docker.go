package docker

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/events"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"
	"github.com/serverdeck/serverdeck-backend/internal/metrics"
)

// ContainerSummary matches the schema in SHARED_SPEC.md.
type ContainerSummary struct {
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	Image            string   `json:"image"`
	State            string   `json:"state"`
	Status           string   `json:"status"`
	Health           string   `json:"health"`
	Stack            string   `json:"stack"`
	CreatedAt        int64    `json:"created_at"`
	Ports            []string `json:"ports"`
	CPUPercent       float64  `json:"cpu_percent"`
	MemoryUsageBytes uint64   `json:"memory_usage_bytes"`
	MemoryLimitBytes uint64   `json:"memory_limit_bytes"`
}

// ContainerStats matches the schema in SHARED_SPEC.md.
type ContainerStats struct {
	ID               string  `json:"id"`
	Name             string  `json:"name"`
	CPUPercent       float64 `json:"cpu_percent"`
	MemoryUsageBytes uint64  `json:"memory_usage_bytes"`
	MemoryLimitBytes uint64  `json:"memory_limit_bytes"`
	MemoryPercent    float64 `json:"memory_percent"`
	NetworkRxBytes   uint64  `json:"network_rx_bytes"`
	NetworkTxBytes   uint64  `json:"network_tx_bytes"`
	BlockReadBytes   uint64  `json:"block_read_bytes"`
	BlockWriteBytes  uint64  `json:"block_write_bytes"`
}

// ContainerLogsResponse matches the schema in SHARED_SPEC.md.
type ContainerLogsResponse struct {
	ContainerID string   `json:"container_id"`
	Lines       []string `json:"lines"`
}

// ContainerActionResponse matches the schema in SHARED_SPEC.md.
type ContainerActionResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

// ContainerEventData matches the schema in SHARED_SPEC.md.
type ContainerEventData struct {
	ContainerID string `json:"container_id"`
	Action      string `json:"action"`
	Status      string `json:"status"`
}

// PruneReport details the outcome of a Docker system prune operation.
type PruneReport struct {
	ContainersDeleted int    `json:"containers_deleted"`
	ImagesDeleted     int    `json:"images_deleted"`
	SpaceReclaimed    uint64 `json:"space_reclaimed_bytes"`
}

// Client defines the interface for interacting with Docker.
type Client interface {
	ListContainers(ctx context.Context) ([]ContainerSummary, error)
	GetContainerStats(ctx context.Context, id string) (*ContainerStats, error)
	GetContainerLogs(ctx context.Context, id string, tail int, timestamps bool) (*ContainerLogsResponse, error)
	StartContainer(ctx context.Context, id string) error
	StopContainer(ctx context.Context, id string) error
	RestartContainer(ctx context.Context, id string) error
	Prune(ctx context.Context) (*PruneReport, error)
	RestartUnhealthy(ctx context.Context) ([]string, error)
	SubscribeEvents(ctx context.Context) (<-chan ContainerEventData, error)
	GetSummary(ctx context.Context) (metrics.ContainersSummary, error)
	IsMock() bool
	Close() error
}

// NewClient initializes a Docker client, falling back to MockClient if unreachable or requested.
func NewClient(ctx context.Context, forceMock bool) Client {
	if forceMock {
		log.Println("[Docker] Mock mode forced via configuration.")
		return NewMockClient()
	}

	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		log.Printf("[Docker] Failed to initialize Docker client (%v). Falling back to mock client.", err)
		return NewMockClient()
	}

	pingCtx, cancel := context.WithTimeout(ctx, 1500*time.Millisecond)
	defer cancel()

	_, err = cli.Ping(pingCtx)
	if err != nil {
		log.Printf("[Docker] Docker daemon ping failed (%v). Falling back to mock client.", err)
		_ = cli.Close()
		return NewMockClient()
	}

	log.Println("[Docker] Connected to Docker daemon successfully.")
	return NewDockerClient(cli)
}

// DockerClient implements Client using the official Docker Engine API.
type DockerClient struct {
	cli *client.Client
}

// NewDockerClient creates a new DockerClient.
func NewDockerClient(cli *client.Client) *DockerClient {
	return &DockerClient{cli: cli}
}

func (d *DockerClient) IsMock() bool {
	return false
}

func (d *DockerClient) Close() error {
	return d.cli.Close()
}

func (d *DockerClient) ListContainers(ctx context.Context) ([]ContainerSummary, error) {
	containers, err := d.cli.ContainerList(ctx, container.ListOptions{All: true})
	if err != nil {
		return nil, fmt.Errorf("list containers: %w", err)
	}

	summaries := make([]ContainerSummary, 0, len(containers))
	for _, c := range containers {
		id := c.ID
		if len(id) > 12 {
			id = id[:12]
		}

		name := ""
		if len(c.Names) > 0 {
			name = strings.TrimPrefix(c.Names[0], "/")
		}

		stack := c.Labels["com.docker.compose.project"]
		if stack == "" {
			stack = c.Labels["com.docker.stack.namespace"]
		}

		ports := make([]string, 0, len(c.Ports))
		for _, p := range c.Ports {
			if p.PublicPort > 0 {
				ports = append(ports, fmt.Sprintf("%d:%d", p.PublicPort, p.PrivatePort))
			} else {
				ports = append(ports, fmt.Sprintf("%d/%s", p.PrivatePort, p.Type))
			}
		}

		health := extractHealth(c.Status)

		summary := ContainerSummary{
			ID:               id,
			Name:             name,
			Image:            c.Image,
			State:            c.State,
			Status:           c.Status,
			Health:           health,
			Stack:            stack,
			CreatedAt:        c.Created,
			Ports:            ports,
			CPUPercent:       0.0,
			MemoryUsageBytes: 0,
			MemoryLimitBytes: 0,
		}

		summaries = append(summaries, summary)
	}

	return summaries, nil
}

func (d *DockerClient) GetContainerStats(ctx context.Context, id string) (*ContainerStats, error) {
	resp, err := d.cli.ContainerStats(ctx, id, false)
	if err != nil {
		return nil, fmt.Errorf("get container stats: %w", err)
	}
	defer resp.Body.Close()

	var stats types.StatsJSON
	if err := json.NewDecoder(resp.Body).Decode(&stats); err != nil {
		return nil, fmt.Errorf("decode container stats: %w", err)
	}

	name := strings.TrimPrefix(stats.Name, "/")
	cleanID := id
	if len(cleanID) > 12 {
		cleanID = cleanID[:12]
	}

	cpuPercent := calculateCPUPercent(&stats)
	memUsage, memLimit, memPercent := calculateMemory(&stats)
	rx, tx := calculateNetwork(&stats)
	blkRead, blkWrite := calculateBlockIO(&stats)

	return &ContainerStats{
		ID:               cleanID,
		Name:             name,
		CPUPercent:       cpuPercent,
		MemoryUsageBytes: memUsage,
		MemoryLimitBytes: memLimit,
		MemoryPercent:    memPercent,
		NetworkRxBytes:   rx,
		NetworkTxBytes:   tx,
		BlockReadBytes:   blkRead,
		BlockWriteBytes:  blkWrite,
	}, nil
}

func (d *DockerClient) GetContainerLogs(ctx context.Context, id string, tail int, timestamps bool) (*ContainerLogsResponse, error) {
	tailStr := "200"
	if tail > 0 {
		tailStr = strconv.Itoa(tail)
	}

	reader, err := d.cli.ContainerLogs(ctx, id, container.LogsOptions{
		ShowStdout: true,
		ShowStderr: true,
		Tail:       tailStr,
		Timestamps: timestamps,
	})
	if err != nil {
		return nil, fmt.Errorf("container logs: %w", err)
	}
	defer reader.Close()

	lines := demuxDockerLogs(reader)
	cleanID := id
	if len(cleanID) > 12 {
		cleanID = cleanID[:12]
	}

	return &ContainerLogsResponse{
		ContainerID: cleanID,
		Lines:       lines,
	}, nil
}

func (d *DockerClient) StartContainer(ctx context.Context, id string) error {
	return d.cli.ContainerStart(ctx, id, container.StartOptions{})
}

func (d *DockerClient) StopContainer(ctx context.Context, id string) error {
	timeout := 15
	return d.cli.ContainerStop(ctx, id, container.StopOptions{Timeout: &timeout})
}

func (d *DockerClient) RestartContainer(ctx context.Context, id string) error {
	timeout := 15
	return d.cli.ContainerRestart(ctx, id, container.StopOptions{Timeout: &timeout})
}

// Prune cleans stopped containers and dangling images.
func (d *DockerClient) Prune(ctx context.Context) (*PruneReport, error) {
	report := &PruneReport{}
	if cReport, err := d.cli.ContainersPrune(ctx, filters.NewArgs()); err == nil {
		report.ContainersDeleted = len(cReport.ContainersDeleted)
		report.SpaceReclaimed += cReport.SpaceReclaimed
	}
	if iReport, err := d.cli.ImagesPrune(ctx, filters.NewArgs()); err == nil {
		report.ImagesDeleted = len(iReport.ImagesDeleted)
		report.SpaceReclaimed += iReport.SpaceReclaimed
	}
	return report, nil
}

// RestartUnhealthy restarts all containers that are exited or unhealthy.
func (d *DockerClient) RestartUnhealthy(ctx context.Context) ([]string, error) {
	containers, err := d.ListContainers(ctx)
	if err != nil {
		return nil, err
	}
	var restarted []string
	for _, c := range containers {
		if c.State == "exited" || c.Health == "unhealthy" {
			if err := d.RestartContainer(ctx, c.ID); err == nil {
				restarted = append(restarted, c.Name)
			}
		}
	}
	return restarted, nil
}

func (d *DockerClient) SubscribeEvents(ctx context.Context) (<-chan ContainerEventData, error) {
	eventFilter := filters.NewArgs(filters.Arg("type", "container"))
	msgs, errs := d.cli.Events(ctx, events.ListOptions{Filters: eventFilter})

	outChan := make(chan ContainerEventData, 64)
	go func() {
		defer close(outChan)
		for {
			select {
			case <-ctx.Done():
				return
			case err := <-errs:
				if err != nil && !errors.Is(err, io.EOF) && !errors.Is(err, context.Canceled) {
					log.Printf("[Docker] Events stream error: %v", err)
				}
				return
			case msg, ok := <-msgs:
				if !ok {
					return
				}
				cid := msg.Actor.ID
				if len(cid) > 12 {
					cid = cid[:12]
				}
				outChan <- ContainerEventData{
					ContainerID: cid,
					Action:      string(msg.Action),
					Status:      msg.Status,
				}
			}
		}
	}()

	return outChan, nil
}

func (d *DockerClient) GetSummary(ctx context.Context) (metrics.ContainersSummary, error) {
	containers, err := d.cli.ContainerList(ctx, container.ListOptions{All: true})
	if err != nil {
		return metrics.ContainersSummary{}, err
	}

	summary := metrics.ContainersSummary{
		Total: len(containers),
	}

	for _, c := range containers {
		switch strings.ToLower(c.State) {
		case "running":
			summary.Running++
		case "exited", "dead":
			summary.Stopped++
		}

		if strings.Contains(strings.ToLower(c.Status), "(unhealthy)") {
			summary.Unhealthy++
		}
	}

	return summary, nil
}

// Helpers for stats calculations
func calculateCPUPercent(stats *types.StatsJSON) float64 {
	cpuDelta := float64(stats.CPUStats.CPUUsage.TotalUsage) - float64(stats.PreCPUStats.CPUUsage.TotalUsage)
	systemDelta := float64(stats.CPUStats.SystemUsage) - float64(stats.PreCPUStats.SystemUsage)
	onlineCPUs := float64(stats.CPUStats.OnlineCPUs)
	if onlineCPUs == 0 {
		onlineCPUs = float64(len(stats.CPUStats.CPUUsage.PercpuUsage))
	}
	if onlineCPUs == 0 {
		onlineCPUs = 1
	}

	if systemDelta > 0 && cpuDelta > 0 {
		percent := (cpuDelta / systemDelta) * onlineCPUs * 100.0
		return math.Round(percent*10) / 10
	}
	return 0.0
}

func calculateMemory(stats *types.StatsJSON) (uint64, uint64, float64) {
	usage := stats.MemoryStats.Usage
	limit := stats.MemoryStats.Limit

	if cache, ok := stats.MemoryStats.Stats["cache"]; ok && usage > cache {
		usage -= cache
	} else if inactiveFile, ok := stats.MemoryStats.Stats["inactive_file"]; ok && usage > inactiveFile {
		usage -= inactiveFile
	}

	var percent float64 = 0.0
	if limit > 0 {
		percent = math.Round((float64(usage)/float64(limit)*100.0)*10) / 10
	}

	return usage, limit, percent
}

func calculateNetwork(stats *types.StatsJSON) (uint64, uint64) {
	var rx, tx uint64
	for _, n := range stats.Networks {
		rx += n.RxBytes
		tx += n.TxBytes
	}
	return rx, tx
}

func calculateBlockIO(stats *types.StatsJSON) (uint64, uint64) {
	var read, write uint64
	for _, entry := range stats.BlkioStats.IoServiceBytesRecursive {
		switch strings.ToLower(entry.Op) {
		case "read":
			read += entry.Value
		case "write":
			write += entry.Value
		}
	}
	return read, write
}

func extractHealth(status string) string {
	lower := strings.ToLower(status)
	if strings.Contains(lower, "(healthy)") {
		return "healthy"
	}
	if strings.Contains(lower, "(unhealthy)") {
		return "unhealthy"
	}
	if strings.Contains(lower, "(health: starting)") {
		return "starting"
	}
	return "none"
}

// demuxDockerLogs handles both Docker multiplexed stream frames (8-byte header) and raw TTY logs.
func demuxDockerLogs(r io.Reader) []string {
	var lines []string
	buf := new(bytes.Buffer)
	_, _ = buf.ReadFrom(r)
	data := buf.Bytes()

	// Check if data begins with Docker multiplexing header: [1|2, 0, 0, 0, s0, s1, s2, s3]
	if len(data) >= 8 && (data[0] == 1 || data[0] == 2) && data[1] == 0 && data[2] == 0 && data[3] == 0 {
		cursor := 0
		for cursor+8 <= len(data) {
			_ = data[cursor] // stream type (1=stdout, 2=stderr)
			frameLen := int(binary.BigEndian.Uint32(data[cursor+4 : cursor+8]))
			cursor += 8
			if cursor+frameLen > len(data) {
				frame := strings.TrimSpace(string(data[cursor:]))
				if frame != "" {
					lines = append(lines, strings.Split(frame, "\n")...)
				}
				break
			}
			payload := strings.TrimRight(string(data[cursor:cursor+frameLen]), "\r\n")
			for _, line := range strings.Split(payload, "\n") {
				trimmed := strings.TrimRight(line, "\r")
				if trimmed != "" {
					lines = append(lines, trimmed)
				}
			}
			cursor += frameLen
		}
		return lines
	}

	// Raw lines scanner fallback
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := strings.TrimRight(scanner.Text(), "\r")
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}

// MockClient provides an in-memory, fully functional container manager for testing and macOS dev.
type MockClient struct {
	mu         sync.RWMutex
	containers map[string]*ContainerSummary
	stats      map[string]*ContainerStats
	logs       map[string][]string
	eventsChan chan ContainerEventData
}

// NewMockClient initializes a mock client pre-loaded with realistic homelab containers.
func NewMockClient() *MockClient {
	c := &MockClient{
		containers: make(map[string]*ContainerSummary),
		stats:      make(map[string]*ContainerStats),
		logs:       make(map[string][]string),
		eventsChan: make(chan ContainerEventData, 100),
	}

	// 1. OpenWebUI
	c.containers["c1a2b3c4d5e6"] = &ContainerSummary{
		ID:               "c1a2b3c4d5e6",
		Name:             "openwebui",
		Image:            "ghcr.io/open-webui/open-webui:main",
		State:            "running",
		Status:           "Up 3 days (healthy)",
		Health:           "healthy",
		Stack:            "OpenWebUI",
		CreatedAt:        1700000000,
		Ports:            []string{"8080:8080"},
		CPUPercent:       2.4,
		MemoryUsageBytes: 268435456,
		MemoryLimitBytes: 16777216000,
	}
	c.stats["c1a2b3c4d5e6"] = &ContainerStats{
		ID:               "c1a2b3c4d5e6",
		Name:             "openwebui",
		CPUPercent:       2.4,
		MemoryUsageBytes: 268435456,
		MemoryLimitBytes: 16777216000,
		MemoryPercent:    1.6,
		NetworkRxBytes:   52428800,
		NetworkTxBytes:   18874368,
		BlockReadBytes:   1048576,
		BlockWriteBytes:  4194304,
	}
	c.logs["c1a2b3c4d5e6"] = []string{
		"2026-03-30T10:00:00Z [info] Server started on port 8080",
		"2026-03-30T10:00:05Z [info] Connected to database",
		"2026-03-30T10:00:10Z [info] Ready for client connections",
	}

	// 2. Portainer
	c.containers["d2e3f4a5b6c7"] = &ContainerSummary{
		ID:               "d2e3f4a5b6c7",
		Name:             "portainer",
		Image:            "portainer/portainer-ce:latest",
		State:            "running",
		Status:           "Up 5 days (healthy)",
		Health:           "healthy",
		Stack:            "Management",
		CreatedAt:        1699800000,
		Ports:            []string{"9000:9000", "9443:9443"},
		CPUPercent:       0.8,
		MemoryUsageBytes: 67108864,
		MemoryLimitBytes: 16777216000,
	}
	c.stats["d2e3f4a5b6c7"] = &ContainerStats{
		ID:               "d2e3f4a5b6c7",
		Name:             "portainer",
		CPUPercent:       0.8,
		MemoryUsageBytes: 67108864,
		MemoryLimitBytes: 16777216000,
		MemoryPercent:    0.4,
		NetworkRxBytes:   12451840,
		NetworkTxBytes:   8388608,
		BlockReadBytes:   524288,
		BlockWriteBytes:  2097152,
	}
	c.logs["d2e3f4a5b6c7"] = []string{
		"2026-03-28T08:00:00Z [info] Starting Portainer 2.21.0...",
		"2026-03-28T08:00:01Z [info] Portainer listening on :9000 and :9443",
	}

	// 3. qBittorrent
	c.containers["e3f4a5b6c7d8"] = &ContainerSummary{
		ID:               "e3f4a5b6c7d8",
		Name:             "qbittorrent",
		Image:            "lscr.io/linuxserver/qbittorrent:latest",
		State:            "running",
		Status:           "Up 12 days",
		Health:           "healthy",
		Stack:            "Media",
		CreatedAt:        1699000000,
		Ports:            []string{"8081:8080", "6881:6881"},
		CPUPercent:       5.1,
		MemoryUsageBytes: 536870912,
		MemoryLimitBytes: 16777216000,
	}
	c.stats["e3f4a5b6c7d8"] = &ContainerStats{
		ID:               "e3f4a5b6c7d8",
		Name:             "qbittorrent",
		CPUPercent:       5.1,
		MemoryUsageBytes: 536870912,
		MemoryLimitBytes: 16777216000,
		MemoryPercent:    3.2,
		NetworkRxBytes:   209715200,
		NetworkTxBytes:   104857600,
		BlockReadBytes:   20971520,
		BlockWriteBytes:  41943040,
	}
	c.logs["e3f4a5b6c7d8"] = []string{
		"2026-03-20T12:00:00Z [info] qBittorrent WebUI running on 0.0.0.0:8080",
		"2026-03-20T12:00:02Z [info] DHT and PeX initialized successfully",
	}

	// 4. Radarr
	c.containers["f4a5b6c7d8e9"] = &ContainerSummary{
		ID:               "f4a5b6c7d8e9",
		Name:             "radarr",
		Image:            "lscr.io/linuxserver/radarr:latest",
		State:            "running",
		Status:           "Up 12 days",
		Health:           "healthy",
		Stack:            "Media",
		CreatedAt:        1699000000,
		Ports:            []string{"7878:7878"},
		CPUPercent:       1.2,
		MemoryUsageBytes: 167772160,
		MemoryLimitBytes: 16777216000,
	}
	c.stats["f4a5b6c7d8e9"] = &ContainerStats{
		ID:               "f4a5b6c7d8e9",
		Name:             "radarr",
		CPUPercent:       1.2,
		MemoryUsageBytes: 167772160,
		MemoryLimitBytes: 16777216000,
		MemoryPercent:    1.0,
		NetworkRxBytes:   10485760,
		NetworkTxBytes:   5242880,
		BlockReadBytes:   1048576,
		BlockWriteBytes:  1048576,
	}
	c.logs["f4a5b6c7d8e9"] = []string{
		"2026-03-20T12:00:10Z [info] Radarr version 5.3.6 starting up",
		"2026-03-20T12:00:15Z [info] Listening on 0.0.0.0:7878",
	}

	// 5. Stopped Backup Worker
	c.containers["b6c7d8e9f0a1"] = &ContainerSummary{
		ID:               "b6c7d8e9f0a1",
		Name:             "backup-worker",
		Image:            "alpine:latest",
		State:            "exited",
		Status:           "Exited (0) 5 hours ago",
		Health:           "none",
		Stack:            "Maintenance",
		CreatedAt:        1699900000,
		Ports:            []string{},
		CPUPercent:       0.0,
		MemoryUsageBytes: 0,
		MemoryLimitBytes: 16777216000,
	}
	c.stats["b6c7d8e9f0a1"] = &ContainerStats{
		ID:               "b6c7d8e9f0a1",
		Name:             "backup-worker",
		CPUPercent:       0.0,
		MemoryUsageBytes: 0,
		MemoryLimitBytes: 16777216000,
		MemoryPercent:    0.0,
		NetworkRxBytes:   0,
		NetworkTxBytes:   0,
		BlockReadBytes:   0,
		BlockWriteBytes:  0,
	}
	c.logs["b6c7d8e9f0a1"] = []string{
		"2026-03-30T05:00:00Z [info] Backup task started",
		"2026-03-30T05:02:15Z [info] Backup completed. Exiting.",
	}

	return c
}

func (m *MockClient) IsMock() bool {
	return true
}

func (m *MockClient) Close() error {
	return nil
}

func (m *MockClient) findContainer(idOrName string) (*ContainerSummary, string) {
	// Look up by exact ID or shortened ID or Name
	for k, c := range m.containers {
		if k == idOrName || strings.HasPrefix(k, idOrName) || c.Name == idOrName {
			return c, k
		}
	}
	return nil, ""
}

func (m *MockClient) ListContainers(ctx context.Context) ([]ContainerSummary, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	res := make([]ContainerSummary, 0, len(m.containers))
	for _, c := range m.containers {
		res = append(res, *c)
	}
	return res, nil
}

func (m *MockClient) GetContainerStats(ctx context.Context, id string) (*ContainerStats, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	_, realID := m.findContainer(id)
	if realID == "" {
		return nil, fmt.Errorf("container not found: %s", id)
	}

	st, ok := m.stats[realID]
	if !ok {
		return nil, fmt.Errorf("stats not found for container: %s", id)
	}
	return st, nil
}

func (m *MockClient) GetContainerLogs(ctx context.Context, id string, tail int, timestamps bool) (*ContainerLogsResponse, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	_, realID := m.findContainer(id)
	if realID == "" {
		return nil, fmt.Errorf("container not found: %s", id)
	}

	lines := m.logs[realID]
	if tail > 0 && len(lines) > tail {
		lines = lines[len(lines)-tail:]
	}

	return &ContainerLogsResponse{
		ContainerID: realID,
		Lines:       lines,
	}, nil
}

func (m *MockClient) StartContainer(ctx context.Context, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	c, realID := m.findContainer(id)
	if realID == "" {
		return fmt.Errorf("container not found: %s", id)
	}

	c.State = "running"
	c.Status = "Up less than a minute"

	select {
	case m.eventsChan <- ContainerEventData{
		ContainerID: realID,
		Action:      "start",
		Status:      "running",
	}:
	default:
	}

	return nil
}

func (m *MockClient) StopContainer(ctx context.Context, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	c, realID := m.findContainer(id)
	if realID == "" {
		return fmt.Errorf("container not found: %s", id)
	}

	c.State = "exited"
	c.Status = "Exited (0) less than a minute ago"

	select {
	case m.eventsChan <- ContainerEventData{
		ContainerID: realID,
		Action:      "stop",
		Status:      "exited",
	}:
	default:
	}

	return nil
}

func (m *MockClient) RestartContainer(ctx context.Context, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	c, realID := m.findContainer(id)
	if realID == "" {
		return fmt.Errorf("container not found: %s", id)
	}

	c.State = "running"
	c.Status = "Up less than a minute"

	select {
	case m.eventsChan <- ContainerEventData{
		ContainerID: realID,
		Action:      "restart",
		Status:      "running",
	}:
	default:
	}

	return nil
}

func (m *MockClient) SubscribeEvents(ctx context.Context) (<-chan ContainerEventData, error) {
	return m.eventsChan, nil
}

func (m *MockClient) GetSummary(ctx context.Context) (metrics.ContainersSummary, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	summary := metrics.ContainersSummary{
		Total: len(m.containers),
	}
	for _, c := range m.containers {
		switch strings.ToLower(c.State) {
		case "running":
			summary.Running++
		case "exited", "dead":
			summary.Stopped++
		}
		if c.Health == "unhealthy" {
			summary.Unhealthy++
		}
	}
	return summary, nil
}

func (m *MockClient) Prune(ctx context.Context) (*PruneReport, error) {
	return &PruneReport{
		ContainersDeleted: 2,
		ImagesDeleted:     4,
		SpaceReclaimed:    1425800000,
	}, nil
}

func (m *MockClient) RestartUnhealthy(ctx context.Context) ([]string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var restarted []string
	for _, c := range m.containers {
		if c.State == "exited" || c.Health == "unhealthy" {
			c.State = "running"
			c.Status = "Up less than a minute"
			restarted = append(restarted, c.Name)
		}
	}
	return restarted, nil
}
