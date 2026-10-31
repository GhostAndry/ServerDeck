package metrics

import (
	"context"
	"testing"
)

func TestMockCollector(t *testing.T) {
	mock := NewMockCollector()
	ctx := context.Background()
	summary := ContainersSummary{
		Total:     12,
		Running:   10,
		Stopped:   2,
		Unhealthy: 0,
	}

	overview, err := mock.GetHostOverview(ctx, summary)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if overview.Hostname != "srv-01" {
		t.Errorf("expected hostname srv-01, got %s", overview.Hostname)
	}
	if overview.ContainersSummary.Total != 12 {
		t.Errorf("expected 12 containers total, got %d", overview.ContainersSummary.Total)
	}
	if len(overview.Disks) < 2 {
		t.Errorf("expected at least 2 disks, got %d", len(overview.Disks))
	}
	if overview.CPU.Cores != 4 {
		t.Errorf("expected 4 CPU cores, got %d", overview.CPU.Cores)
	}
	if overview.CPU.TemperatureCelsius == nil || *overview.CPU.TemperatureCelsius != 42.5 {
		t.Errorf("expected 42.5 temperature, got %v", overview.CPU.TemperatureCelsius)
	}
}

func TestSystemCollector(t *testing.T) {
	collector := NewSystemCollector()
	ctx := context.Background()
	summary := ContainersSummary{
		Total:     5,
		Running:   4,
		Stopped:   1,
		Unhealthy: 0,
	}

	overview, err := collector.GetHostOverview(ctx, summary)
	if err != nil {
		t.Fatalf("system collector failed: %v", err)
	}

	if overview.Hostname == "" {
		t.Errorf("expected non-empty hostname")
	}
	if overview.OS == "" {
		t.Errorf("expected non-empty OS name")
	}
	if overview.CPU.Cores <= 0 {
		t.Errorf("expected at least 1 core, got %d", overview.CPU.Cores)
	}
	if overview.Memory.TotalBytes == 0 {
		t.Errorf("expected total memory > 0")
	}
	if len(overview.Disks) == 0 {
		t.Errorf("expected at least 1 disk")
	}
	if overview.ContainersSummary.Total != 5 {
		t.Errorf("expected containers summary total 5, got %d", overview.ContainersSummary.Total)
	}
}
