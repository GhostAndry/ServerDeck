package docker

import (
	"bytes"
	"context"
	"encoding/binary"
	"testing"
)

func TestMockClientLifecycle(t *testing.T) {
	client := NewMockClient()
	ctx := context.Background()

	// 1. List containers
	containers, err := client.ListContainers(ctx)
	if err != nil {
		t.Fatalf("failed to list containers: %v", err)
	}
	if len(containers) < 4 {
		t.Errorf("expected at least 4 mock containers, got %d", len(containers))
	}

	// 2. Container stats
	targetID := "c1a2b3c4d5e6" // openwebui
	stats, err := client.GetContainerStats(ctx, targetID)
	if err != nil {
		t.Fatalf("failed to get stats: %v", err)
	}
	if stats.Name != "openwebui" {
		t.Errorf("expected container name openwebui, got %s", stats.Name)
	}
	if stats.CPUPercent != 2.4 {
		t.Errorf("expected CPU 2.4, got %v", stats.CPUPercent)
	}

	// 3. Container logs
	logsResp, err := client.GetContainerLogs(ctx, targetID, 200, true)
	if err != nil {
		t.Fatalf("failed to get logs: %v", err)
	}
	if len(logsResp.Lines) == 0 {
		t.Errorf("expected non-empty log lines")
	}

	// 4. Test Stop
	if err := client.StopContainer(ctx, targetID); err != nil {
		t.Fatalf("failed to stop container: %v", err)
	}
	listAfterStop, _ := client.ListContainers(ctx)
	for _, c := range listAfterStop {
		if c.ID == targetID {
			if c.State != "exited" {
				t.Errorf("expected state exited, got %s", c.State)
			}
		}
	}

	// 5. Test Start
	if err := client.StartContainer(ctx, targetID); err != nil {
		t.Fatalf("failed to start container: %v", err)
	}
	listAfterStart, _ := client.ListContainers(ctx)
	for _, c := range listAfterStart {
		if c.ID == targetID {
			if c.State != "running" {
				t.Errorf("expected state running, got %s", c.State)
			}
		}
	}

	// 6. Test Restart
	if err := client.RestartContainer(ctx, targetID); err != nil {
		t.Fatalf("failed to restart container: %v", err)
	}

	// 7. Test Summary
	summary, err := client.GetSummary(ctx)
	if err != nil {
		t.Fatalf("failed to get summary: %v", err)
	}
	if summary.Total != len(containers) {
		t.Errorf("expected summary total %d, got %d", len(containers), summary.Total)
	}
	if summary.Running < 3 {
		t.Errorf("expected at least 3 running containers, got %d", summary.Running)
	}
}

func TestDemuxDockerLogs(t *testing.T) {
	// Construct simulated multiplexed docker frames:
	// Frame 1: stdout: "line 1\n"
	// Frame 2: stderr: "line 2\n"
	buf := new(bytes.Buffer)

	// Frame 1
	payload1 := []byte("line 1\n")
	header1 := make([]byte, 8)
	header1[0] = 1 // stdout
	binary.BigEndian.PutUint32(header1[4:], uint32(len(payload1)))
	buf.Write(header1)
	buf.Write(payload1)

	// Frame 2
	payload2 := []byte("line 2\n")
	header2 := make([]byte, 8)
	header2[0] = 2 // stderr
	binary.BigEndian.PutUint32(header2[4:], uint32(len(payload2)))
	buf.Write(header2)
	buf.Write(payload2)

	lines := demuxDockerLogs(buf)
	if len(lines) != 2 {
		t.Fatalf("expected 2 lines, got %d (%v)", len(lines), lines)
	}
	if lines[0] != "line 1" {
		t.Errorf("expected 'line 1', got '%s'", lines[0])
	}
	if lines[1] != "line 2" {
		t.Errorf("expected 'line 2', got '%s'", lines[1])
	}

	// Test fallback plain text logs
	plainBuf := bytes.NewBufferString("plain line 1\nplain line 2\n")
	plainLines := demuxDockerLogs(plainBuf)
	if len(plainLines) != 2 {
		t.Fatalf("expected 2 lines from plain text, got %d", len(plainLines))
	}
}
