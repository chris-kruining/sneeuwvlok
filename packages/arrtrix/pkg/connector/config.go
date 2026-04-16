package connector

import (
	_ "embed"
	"fmt"
	"net/http"

	up "go.mau.fi/util/configupgrade"
	"maunium.net/go/mautrix/bridgev2"

	"sneeuwvlok/packages/arrtrix/pkg/webhook"
)

//go:embed example-config.yaml
var ExampleConfig string

type Config struct {
	Webhooks WebhooksConfig `yaml:"webhooks"`
}

type WebhooksConfig struct {
	Radarr webhook.RadarrConfig `yaml:"radarr"`
}

func (c *Config) applyDefaults() {
	c.Webhooks.Radarr.ApplyDefaults()
}

func (c *Config) Validate() error {
	return c.Webhooks.Radarr.Validate()
}

func upgradeConfig(helper up.Helper) {}

func (s *ArrtrixConnector) GetConfig() (string, any, up.Upgrader) {
	s.Config.applyDefaults()
	return ExampleConfig, &s.Config, up.SimpleUpgrader(upgradeConfig)
}

func (s *ArrtrixConnector) ValidateConfig() error {
	s.Config.applyDefaults()
	return s.Config.Validate()
}

func (s *ArrtrixConnector) MountRoutes(router *http.ServeMux) error {
	s.Config.applyDefaults()
	if s.Bridge == nil {
		return fmt.Errorf("bridge is not initialized")
	}
	return webhook.MountRadarr(router, s.Bridge, s.Config.Webhooks.Radarr)
}

var _ bridgev2.ConfigValidatingNetwork = (*ArrtrixConnector)(nil)
