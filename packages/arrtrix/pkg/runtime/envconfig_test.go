package runtime

import (
	"os"
	"testing"

	"maunium.net/go/mautrix/bridgev2/bridgeconfig"

	"sneeuwvlok/packages/arrtrix/pkg/connector"
)

func TestUpdateConfigFromEnvSupportsFlatUnderscorePaths(t *testing.T) {
	t.Setenv("ARRTRIX_NETWORK_CONTENT_MOVIES_APIKEY", "radarr-secret")

	cfg := &bridgeconfig.Config{}
	network := &connector.Config{}
	if err := updateConfigFromEnv(cfg, network, "ARRTRIX_"); err != nil {
		t.Fatalf("updateConfigFromEnv returned error: %v", err)
	}

	if network.Content.Movies.APIKey != "radarr-secret" {
		t.Fatalf("expected movies api key to be overridden, got %q", network.Content.Movies.APIKey)
	}
}

func TestUpdateConfigFromEnvSupportsExplicitUnderscoredFieldNames(t *testing.T) {
	t.Setenv("ARRTRIX_NETWORK_CONTENT_MOVIES_ROOT_FOLDER_PATH", "/data/movies")

	cfg := &bridgeconfig.Config{}
	network := &connector.Config{}
	if err := updateConfigFromEnv(cfg, network, "ARRTRIX_"); err != nil {
		t.Fatalf("updateConfigFromEnv returned error: %v", err)
	}

	if network.Content.Movies.RootFolderPath != "/data/movies" {
		t.Fatalf("expected root folder path to be overridden, got %q", network.Content.Movies.RootFolderPath)
	}
}

func TestUpdateConfigFromEnvSupportsDoubleUnderscorePaths(t *testing.T) {
	t.Setenv("ARRTRIX_NETWORK__CONTENT__SERIES__API_KEY", "sonarr-secret")

	cfg := &bridgeconfig.Config{}
	network := &connector.Config{}
	if err := updateConfigFromEnv(cfg, network, "ARRTRIX_"); err != nil {
		t.Fatalf("updateConfigFromEnv returned error: %v", err)
	}

	if network.Content.Series.APIKey != "sonarr-secret" {
		t.Fatalf("expected series api key to be overridden, got %q", network.Content.Series.APIKey)
	}
}

func TestMain(m *testing.M) {
	code := m.Run()
	os.Exit(code)
}
