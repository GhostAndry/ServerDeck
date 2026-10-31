package hostctrl

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/mem"
)

// DefaultBridgeSocketPath is where the Rust bridge daemon exposes its UNIX domain socket.
const DefaultBridgeSocketPath = "/var/run/serverdeck/bridge.sock"

// ExecRequest defines the shell command to run on the host.
type ExecRequest struct {
	Command string `json:"command"`
}

// ExecResult captures standard output, errors, and return code.
type ExecResult struct {
	Command    string `json:"command"`
	Stdout     string `json:"stdout"`
	Stderr     string `json:"stderr"`
	ExitCode   int    `json:"exit_code"`
	DurationMs int64  `json:"duration_ms"`
}

// BridgeRequest matches the JSON schema expected by the Rust bridge.
type BridgeRequest struct {
	Action    string `json:"action"`
	Command   string `json:"command,omitempty"`
	DelaySecs ulong  `json:"delay_secs,omitempty"`
}

type ulong = uint64

// BridgeResponse matches the generic JSON reply from the Rust bridge.
type BridgeResponse struct {
	Success    bool   `json:"success,omitempty"`
	Command    string `json:"command,omitempty"`
	Stdout     string `json:"stdout,omitempty"`
	Stderr     string `json:"stderr,omitempty"`
	ExitCode   int    `json:"exit_code,omitempty"`
	DurationMs int64  `json:"duration_ms,omitempty"`
	Action     string `json:"action,omitempty"`
	Message    string `json:"message,omitempty"`
	Error      string `json:"error,omitempty"`
}

// DiagnosticReport contains structured system diagnostic details.
type DiagnosticReport struct {
	Hostname       string       `json:"hostname"`
	Platform       string       `json:"platform"`
	Kernel         string       `json:"kernel"`
	Arch           string       `json:"arch"`
	UptimeSeconds  uint64       `json:"uptime_seconds"`
	MemoryTotal    uint64       `json:"memory_total_bytes"`
	MemoryUsed     uint64       `json:"memory_used_bytes"`
	MemoryFree     uint64       `json:"memory_free_bytes"`
	SwapTotal      uint64       `json:"swap_total_bytes"`
	SwapUsed       uint64       `json:"swap_used_bytes"`
	StorageDetails []DiskDetail `json:"storage_details"`
	DiagnosticLogs []string     `json:"diagnostic_logs"`
}

// DiskDetail reports mount point information.
type DiskDetail struct {
	MountPoint   string  `json:"mount_point"`
	Filesystem   string  `json:"filesystem"`
	TotalBytes   int64   `json:"total_bytes"`
	UsedBytes    int64   `json:"used_bytes"`
	UsagePercent float64 `json:"usage_percent"`
}

// HostActionResponse matches the standard action reply.
type HostActionResponse struct {
	Success bool   `json:"success"`
	Action  string `json:"action"`
	Message string `json:"message"`
}

// Manager coordinates host execution via the Rust bridge socket or local fallback.
type Manager struct {
	socketPath string
	isMock     bool
	mu         sync.Mutex
}

// NewManager initializes a new host control manager.
func NewManager(isMock bool) *Manager {
	sock := os.Getenv("SERVERDECK_BRIDGE_SOCKET")
	if sock == "" {
		sock = DefaultBridgeSocketPath
	}
	return &Manager{
		socketPath: sock,
		isMock:     isMock,
	}
}

func (m *Manager) hasBridge() bool {
	if m.isMock {
		return false
	}
	info, err := os.Stat(m.socketPath)
	return err == nil && (info.Mode()&os.ModeSocket != 0 || info.Mode().IsRegular())
}

// callBridge sends a JSON request over the UNIX domain socket to the Rust bridge.
func (m *Manager) callBridge(req any, resp any) error {
	conn, err := net.DialTimeout("unix", m.socketPath, 1500*time.Millisecond)
	if err != nil {
		return fmt.Errorf("connect to host bridge socket (%s): %w", m.socketPath, err)
	}
	defer conn.Close()

	_ = conn.SetDeadline(time.Now().Add(15 * time.Second))

	reqData, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("marshal request: %w", err)
	}
	reqData = append(reqData, '\n')

	if _, err := conn.Write(reqData); err != nil {
		return fmt.Errorf("write to bridge socket: %w", err)
	}

	reader := bufio.NewReader(conn)
	line, err := reader.ReadBytes('\n')
	if err != nil {
		return fmt.Errorf("read response from bridge socket: %w", err)
	}

	if err := json.Unmarshal(line, resp); err != nil {
		return fmt.Errorf("unmarshal bridge response: %w", err)
	}

	return nil
}

// ExecuteHostCommand executes a command on the host. Prefers the native Rust bridge socket.
func (m *Manager) ExecuteHostCommand(ctx context.Context, cmdStr string) (*ExecResult, error) {
	cmdStr = strings.TrimSpace(cmdStr)
	if cmdStr == "" {
		return nil, errors.New("empty command")
	}

	// 1. If Rust host bridge is connected, send command to the bridge
	if m.hasBridge() {
		var bResp BridgeResponse
		bReq := map[string]any{
			"action":  "exec",
			"command": cmdStr,
		}
		if err := m.callBridge(bReq, &bResp); err == nil {
			return &ExecResult{
				Command:    cmdStr,
				Stdout:     bResp.Stdout,
				Stderr:     bResp.Stderr,
				ExitCode:   bResp.ExitCode,
				DurationMs: bResp.DurationMs,
			}, nil
		} else {
			log.Printf("[HostCtrl] Rust bridge error (%v), falling back to nsenter/local.", err)
		}
	}

	// 2. Mock mode fallback
	if m.isMock {
		return &ExecResult{
			Command:    cmdStr,
			Stdout:     fmt.Sprintf("Output simulato per '%s'\nHost: srv-01 (Debian 13)\nKernel: 6.12.113+deb13-amd64\nStato: OK", cmdStr),
			Stderr:     "",
			ExitCode:   0,
			DurationMs: 18,
		}, nil
	}

	// 3. Fallback to nsenter on Linux
	start := time.Now()
	res := &ExecResult{Command: cmdStr}

	var cmd *exec.Cmd
	if _, err := exec.LookPath("nsenter"); err == nil {
		cmd = exec.CommandContext(ctx, "nsenter", "-t", "1", "-m", "-u", "-i", "-n", "-p", "--", "sh", "-c", cmdStr)
	} else {
		cmd = exec.CommandContext(ctx, "sh", "-c", cmdStr)
	}

	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf

	err := cmd.Run()
	res.DurationMs = time.Since(start).Milliseconds()

	const maxOutput = 512 * 1024
	outBytes := stdoutBuf.Bytes()
	if len(outBytes) > maxOutput {
		outBytes = outBytes[:maxOutput]
	}
	res.Stdout = string(outBytes)

	errBytes := stderrBuf.Bytes()
	if len(errBytes) > maxOutput {
		errBytes = errBytes[:maxOutput]
	}
	res.Stderr = string(errBytes)

	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			res.ExitCode = exitErr.ExitCode()
		} else {
			res.ExitCode = 1
			if res.Stderr == "" {
				res.Stderr = err.Error()
			}
		}
	} else {
		res.ExitCode = 0
	}

	return res, nil
}

// Reboot triggers a graceful host reboot via the Rust bridge or systemd.
func (m *Manager) Reboot(delay time.Duration) HostActionResponse {
	m.mu.Lock()
	defer m.mu.Unlock()

	delaySecs := uint64(delay.Seconds())
	if delaySecs == 0 {
		delaySecs = 3
	}

	// 1. Rust host bridge socket
	if m.hasBridge() {
		var bResp BridgeResponse
		bReq := map[string]any{
			"action":     "reboot",
			"delay_secs": delaySecs,
		}
		if err := m.callBridge(bReq, &bResp); err == nil {
			return HostActionResponse{
				Success: true,
				Action:  "reboot",
				Message: fmt.Sprintf("Host reboot scheduled in %d seconds via native Rust bridge", delaySecs),
			}
		}
	}

	if m.isMock {
		log.Println("[HostCtrl] (Mock) Host reboot triggered successfully.")
		return HostActionResponse{
			Success: true,
			Action:  "reboot",
			Message: "Host reboot scheduled in 3 seconds (Mock mode)",
		}
	}

	// 2. Direct systemd fallback
	go func() {
		time.Sleep(delay)
		if _, err := exec.LookPath("nsenter"); err == nil {
			cmd := exec.Command("nsenter", "-t", "1", "-m", "-u", "-i", "-n", "-p", "--", "systemctl", "reboot")
			_ = cmd.Run()
		} else if _, err := os.Stat("/var/run/dbus/system_bus_socket"); err == nil {
			cmd := exec.Command("dbus-send", "--system", "--dest=org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager.Reboot", "boolean:false")
			_ = cmd.Run()
		}
	}()

	return HostActionResponse{
		Success: true,
		Action:  "reboot",
		Message: fmt.Sprintf("Host reboot scheduled in %d seconds", delaySecs),
	}
}

// Shutdown triggers a graceful host power-off via the Rust bridge or systemd.
func (m *Manager) Shutdown(delay time.Duration) HostActionResponse {
	m.mu.Lock()
	defer m.mu.Unlock()

	delaySecs := uint64(delay.Seconds())
	if delaySecs == 0 {
		delaySecs = 3
	}

	// 1. Rust host bridge socket
	if m.hasBridge() {
		var bResp BridgeResponse
		bReq := map[string]any{
			"action":     "shutdown",
			"delay_secs": delaySecs,
		}
		if err := m.callBridge(bReq, &bResp); err == nil {
			return HostActionResponse{
				Success: true,
				Action:  "shutdown",
				Message: fmt.Sprintf("Host power-off scheduled in %d seconds via native Rust bridge", delaySecs),
			}
		}
	}

	if m.isMock {
		log.Println("[HostCtrl] (Mock) Host shutdown triggered successfully.")
		return HostActionResponse{
			Success: true,
			Action:  "shutdown",
			Message: "Host power-off scheduled in 3 seconds (Mock mode)",
		}
	}

	// 2. Direct systemd fallback
	go func() {
		time.Sleep(delay)
		if _, err := exec.LookPath("nsenter"); err == nil {
			cmd := exec.Command("nsenter", "-t", "1", "-m", "-u", "-i", "-n", "-p", "--", "systemctl", "poweroff")
			_ = cmd.Run()
		} else if _, err := os.Stat("/var/run/dbus/system_bus_socket"); err == nil {
			cmd := exec.Command("dbus-send", "--system", "--dest=org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager.PowerOff", "boolean:false")
			_ = cmd.Run()
		}
	}()

	return HostActionResponse{
		Success: true,
		Action:  "shutdown",
		Message: fmt.Sprintf("Host shutdown scheduled in %d seconds", delaySecs),
	}
}

// GetDiagnostics gathers system diagnostic telemetry.
func (m *Manager) GetDiagnostics(ctx context.Context) (*DiagnosticReport, error) {
	report := &DiagnosticReport{
		Hostname: "srv-01",
		Platform: runtime.GOOS,
		Arch:     runtime.GOARCH,
	}

	if hostInfo, err := host.InfoWithContext(ctx); err == nil && hostInfo != nil {
		if hostInfo.Hostname != "" {
			report.Hostname = hostInfo.Hostname
		}
		report.Platform = hostInfo.Platform + " " + hostInfo.PlatformVersion
		report.Kernel = hostInfo.KernelVersion
		report.UptimeSeconds = hostInfo.Uptime
	}

	for _, releasePath := range []string{"/host/root/etc/os-release", "/etc/os-release"} {
		if data, err := os.ReadFile(releasePath); err == nil {
			for _, line := range strings.Split(string(data), "\n") {
				if strings.HasPrefix(line, "PRETTY_NAME=") {
					val := strings.TrimPrefix(line, "PRETTY_NAME=")
					val = strings.Trim(val, "\"")
					if val != "" {
						report.Platform = val
						break
					}
				}
			}
			break
		}
	}

	if vm, err := mem.VirtualMemoryWithContext(ctx); err == nil && vm != nil {
		report.MemoryTotal = vm.Total
		report.MemoryUsed = vm.Used
		report.MemoryFree = vm.Available
	}

	if sw, err := mem.SwapMemoryWithContext(ctx); err == nil && sw != nil {
		report.SwapTotal = sw.Total
		report.SwapUsed = sw.Used
	}

	rootPath := "/"
	if hostRoot := os.Getenv("HOST_ROOT"); hostRoot != "" {
		rootPath = hostRoot
	}
	if u, err := disk.UsageWithContext(ctx, rootPath); err == nil && u != nil {
		report.StorageDetails = append(report.StorageDetails, DiskDetail{
			MountPoint:   "/",
			Filesystem:   u.Fstype,
			TotalBytes:   int64(u.Total),
			UsedBytes:    int64(u.Used),
			UsagePercent: u.UsedPercent,
		})
	}
	if u, err := disk.UsageWithContext(ctx, "/mnt/DATA"); err == nil && u != nil {
		report.StorageDetails = append(report.StorageDetails, DiskDetail{
			MountPoint:   "/mnt/DATA",
			Filesystem:   u.Fstype,
			TotalBytes:   int64(u.Total),
			UsedBytes:    int64(u.Used),
			UsagePercent: u.UsedPercent,
		})
	}

	var logLines []string
	if m.hasBridge() {
		logLines = append(logLines, "Host Bridge: Native Rust Daemon (/run/serverdeck/bridge.sock) [Active]")
	}
	if data, err := os.ReadFile("/proc/version"); err == nil {
		logLines = append(logLines, "Kernel: "+strings.TrimSpace(string(data)))
	}
	if data, err := os.ReadFile("/proc/loadavg"); err == nil {
		logLines = append(logLines, "Load Average: "+strings.TrimSpace(string(data)))
	}
	logLines = append(logLines, fmt.Sprintf("Go Runtime: %s (%s/%s)", runtime.Version(), runtime.GOOS, runtime.GOARCH))
	logLines = append(logLines, fmt.Sprintf("Num CPU Cores: %d", runtime.NumCPU()))

	report.DiagnosticLogs = logLines
	return report, nil
}
