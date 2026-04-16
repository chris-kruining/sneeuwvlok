package observability

import "testing"

func TestConfigDefaults(t *testing.T) {
	var cfg Config
	cfg.ApplyDefaults()

	if cfg.ServiceName != "arrtrix" {
		t.Fatalf("expected default service name arrtrix, got %q", cfg.ServiceName)
	}
	if cfg.ResourceAttributes == nil {
		t.Fatal("expected resource attributes map to be initialized")
	}
	if cfg.Enabled() {
		t.Fatal("expected observability to be disabled by default")
	}
}

func TestParseEndpointSupportsURLAndBareHost(t *testing.T) {
	tests := []struct {
		name      string
		input     string
		wantRaw   string
		insecure  bool
		wantError bool
	}{
		{name: "https url", input: "https://otel.example:4317", wantRaw: "https://otel.example:4317"},
		{name: "http url", input: "http://127.0.0.1:4317", wantRaw: "http://127.0.0.1:4317", insecure: true},
		{name: "bare host", input: "collector:4317", wantRaw: "http://collector:4317", insecure: true},
		{name: "invalid", input: "://bad", wantError: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseEndpoint(tt.input)
			if tt.wantError {
				if err == nil {
					t.Fatal("expected error")
				}
				return
			}
			if err != nil {
				t.Fatalf("parseEndpoint returned error: %v", err)
			}
			if got.raw != tt.wantRaw {
				t.Fatalf("expected raw endpoint %q, got %q", tt.wantRaw, got.raw)
			}
			if got.insecure != tt.insecure {
				t.Fatalf("expected insecure=%t, got %t", tt.insecure, got.insecure)
			}
		})
	}
}
