package connector

import "testing"

func TestConfigDefaultsApplyRadarrWebhookPath(t *testing.T) {
	var cfg Config

	cfg.applyDefaults()

	if cfg.Webhooks.Radarr.Path == "" {
		t.Fatal("expected radarr webhook path default to be set")
	}
}

func TestConfigValidateRejectsEnabledWebhookWithoutSecret(t *testing.T) {
	cfg := Config{}
	cfg.Webhooks.Radarr.Enabled = true
	cfg.applyDefaults()

	if err := cfg.Validate(); err == nil {
		t.Fatal("expected missing secret to fail validation")
	}
}
