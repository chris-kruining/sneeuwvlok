package connector

import (
	_ "embed"
	"fmt"
	"net/http"

	up "go.mau.fi/util/configupgrade"
	"maunium.net/go/mautrix/bridgev2"

	"sneeuwvlok/packages/arrtrix/pkg/arr"
	"sneeuwvlok/packages/arrtrix/pkg/arrclient"
	"sneeuwvlok/packages/arrtrix/pkg/subscriptions"
	"sneeuwvlok/packages/arrtrix/pkg/webhook"
)

//go:embed example-config.yaml
var ExampleConfig string

type Config struct {
	Content ContentConfig `yaml:"content"`
}

type ContentConfig struct {
	Movies arrclient.RadarrConfig `yaml:"movies"`
	Series arrclient.SonarrConfig `yaml:"series"`
}

func upgradeConfig(helper up.Helper) {}

func (s *ArrtrixConnector) GetConfig() (string, any, up.Upgrader) {
	return ExampleConfig, &s.Config, up.SimpleUpgrader(upgradeConfig)
}

func (s *ArrtrixConnector) ValidateConfig() error {
	s.Config.Content.Movies.ApplyDefaults()
	s.Config.Content.Series.ApplyDefaults()
	if err := s.Config.Content.Movies.Validate(); err != nil {
		return err
	}
	if err := s.Config.Content.Series.Validate(); err != nil {
		return err
	}
	return nil
}

func (s *ArrtrixConnector) MountRoutes(router *http.ServeMux) error {
	if s.Bridge == nil {
		return fmt.Errorf("bridge is not initialized")
	}
	return webhook.MountArr(router, s.Bridge, s.Subscriptions())
}

var _ bridgev2.ConfigValidatingNetwork = (*ArrtrixConnector)(nil)
var _ webhook.SubscriptionFilter = (*subscriptions.Repository)(nil)

func (c ContentConfig) Client(contentType arr.ContentType) (arrclient.Client, bool, error) {
	switch contentType {
	case arr.ContentTypeMovies:
		if !c.Movies.Enabled() {
			return nil, false, nil
		}
		client, err := arrclient.NewRadarrClient(c.Movies)
		return client, true, err
	case arr.ContentTypeSeries:
		if !c.Series.Enabled() {
			return nil, false, nil
		}
		client, err := arrclient.NewSonarrClient(c.Series)
		return client, true, err
	default:
		return nil, false, fmt.Errorf("unsupported content type %q", contentType)
	}
}
