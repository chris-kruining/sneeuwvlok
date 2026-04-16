package runtime

import (
	"os"
	"path/filepath"
	"testing"

	"maunium.net/go/mautrix/bridgev2/bridgeconfig"
)

func TestLoadRegistrationTokens(t *testing.T) {
	tempDir := t.TempDir()
	registrationPath := filepath.Join(tempDir, "registration.yaml")
	if err := os.WriteFile(registrationPath, []byte("as_token: app-token\nhs_token: hs-token\n"), 0o600); err != nil {
		t.Fatalf("failed to write registration file: %v", err)
	}

	cfg := &bridgeconfig.Config{}
	main := &Main{RegistrationPath: registrationPath}
	if err := main.loadRegistrationTokens(cfg); err != nil {
		t.Fatalf("loadRegistrationTokens returned error: %v", err)
	}

	if cfg.AppService.ASToken != "app-token" {
		t.Fatalf("expected as token to be loaded, got %q", cfg.AppService.ASToken)
	}
	if cfg.AppService.HSToken != "hs-token" {
		t.Fatalf("expected hs token to be loaded, got %q", cfg.AppService.HSToken)
	}
}
