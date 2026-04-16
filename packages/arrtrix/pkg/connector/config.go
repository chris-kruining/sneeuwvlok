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

type Config struct{}

func upgradeConfig(helper up.Helper) {}

func (s *ArrtrixConnector) GetConfig() (string, any, up.Upgrader) {
	return ExampleConfig, &s.Config, up.SimpleUpgrader(upgradeConfig)
}

func (s *ArrtrixConnector) ValidateConfig() error {
	return nil
}

func (s *ArrtrixConnector) MountRoutes(router *http.ServeMux) error {
	if s.Bridge == nil {
		return fmt.Errorf("bridge is not initialized")
	}
	return webhook.MountArr(router, s.Bridge)
}

var _ bridgev2.ConfigValidatingNetwork = (*ArrtrixConnector)(nil)
