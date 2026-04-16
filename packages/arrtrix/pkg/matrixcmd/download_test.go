package matrixcmd

import (
	"testing"

	"sneeuwvlok/packages/arrtrix/pkg/arrclient"
)

func TestFormatDownloadListFallbackCardUsesMonitoredIcon(t *testing.T) {
	item := arrclient.ManagedItem{
		ID:        1,
		Title:     "Severance",
		Year:      2022,
		Monitored: true,
	}

	fallback := formatDownloadListFallbackCard(item)
	if fallback != "👁 Severance (2022)" {
		t.Fatalf("unexpected monitored fallback %q", fallback)
	}
}

func TestFormatDownloadListFallbackCardUsesUnmonitoredIcon(t *testing.T) {
	item := arrclient.ManagedItem{
		ID:        7,
		Title:     "Andor",
		Year:      2022,
		Monitored: false,
	}

	fallback := formatDownloadListFallbackCard(item)
	if fallback != "🚫 Andor (2022)" {
		t.Fatalf("unexpected unmonitored fallback %q", fallback)
	}
}

func TestMonitoredIcon(t *testing.T) {
	if monitoredIcon(true) != "👁" {
		t.Fatalf("expected monitored icon, got %q", monitoredIcon(true))
	}
	if monitoredIcon(false) != "🚫" {
		t.Fatalf("expected unmonitored icon, got %q", monitoredIcon(false))
	}
}
