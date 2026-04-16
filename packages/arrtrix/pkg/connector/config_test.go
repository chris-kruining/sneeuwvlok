package connector

import "testing"

func TestValidateConfigRejectsPartialMoviesConfig(t *testing.T) {
	conn := &ArrtrixConnector{
		Config: Config{
			Content: ContentConfig{},
		},
	}
	conn.Config.Content.Movies.URL = "http://radarr.test"

	if err := conn.ValidateConfig(); err == nil {
		t.Fatal("expected partial movies config to fail validation")
	}
}

func TestValidateConfigAllowsEmptyContentConfig(t *testing.T) {
	conn := &ArrtrixConnector{}
	if err := conn.ValidateConfig(); err != nil {
		t.Fatalf("ValidateConfig returned error: %v", err)
	}
}
