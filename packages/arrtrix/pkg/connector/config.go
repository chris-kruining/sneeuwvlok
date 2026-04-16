package connector

import (
	_ "embed"

	up "go.mau.fi/util/configupgrade"
)

//go:embed example-config.yaml
var ExampleConfig string

type Config struct{}

func upgradeConfig(helper up.Helper) {}

func (s *ArrtrixConnector) GetConfig() (string, any, up.Upgrader) {
	return ExampleConfig, &s.Config, up.SimpleUpgrader(upgradeConfig)
}
