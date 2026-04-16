package arrclient

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"strings"

	"sneeuwvlok/packages/arrtrix/pkg/arr"
)

type Client interface {
	ContentType() arr.ContentType
	Search(context.Context, string) ([]SearchResult, error)
	List(context.Context, string) ([]ManagedItem, error)
	Add(context.Context, SearchResult) (*ManagedItem, error)
	SetMonitored(context.Context, int64, bool) (*ManagedItem, error)
	Delete(context.Context, int64) error
}

type SearchResult struct {
	LookupID int64
	Title    string
	Year     int
	Overview string
}

type ManagedItem struct {
	ID        int64
	LookupID  int64
	Title     string
	Year      int
	Monitored bool
	Path      string
}

type RadarrConfig struct {
	URL                 string `yaml:"url"`
	APIKey              string `yaml:"api_key"`
	RootFolderPath      string `yaml:"root_folder_path"`
	QualityProfileID    int64  `yaml:"quality_profile_id"`
	MinimumAvailability string `yaml:"minimum_availability"`
	SearchOnAdd         *bool  `yaml:"search_on_add"`
}

type SonarrConfig struct {
	URL               string `yaml:"url"`
	APIKey            string `yaml:"api_key"`
	RootFolderPath    string `yaml:"root_folder_path"`
	QualityProfileID  int64  `yaml:"quality_profile_id"`
	LanguageProfileID int64  `yaml:"language_profile_id"`
	SeasonFolder      *bool  `yaml:"season_folder"`
	SeriesType        string `yaml:"series_type"`
	SearchOnAdd       *bool  `yaml:"search_on_add"`
}

type httpClient struct {
	baseURL    *url.URL
	apiKey     string
	httpClient *http.Client
}

func (c *RadarrConfig) ApplyDefaults() {
	if c.MinimumAvailability == "" {
		c.MinimumAvailability = "released"
	}
}

func (c RadarrConfig) Enabled() bool {
	return strings.TrimSpace(c.URL) != "" || strings.TrimSpace(c.APIKey) != ""
}

func (c RadarrConfig) Validate() error {
	if !c.Enabled() {
		return nil
	}
	switch {
	case strings.TrimSpace(c.URL) == "":
		return fmt.Errorf("network.content.movies.url must be set when movies content is configured")
	case strings.TrimSpace(c.APIKey) == "":
		return fmt.Errorf("network.content.movies.api_key must be set when movies content is configured")
	case strings.TrimSpace(c.RootFolderPath) == "":
		return fmt.Errorf("network.content.movies.root_folder_path must be set when movies content is configured")
	case c.QualityProfileID <= 0:
		return fmt.Errorf("network.content.movies.quality_profile_id must be set when movies content is configured")
	case strings.TrimSpace(c.MinimumAvailability) == "":
		return fmt.Errorf("network.content.movies.minimum_availability must not be empty")
	default:
		return nil
	}
}

func (c RadarrConfig) SearchOnAddValue() bool {
	return boolValue(c.SearchOnAdd, true)
}

func (c *SonarrConfig) ApplyDefaults() {
	if c.SeriesType == "" {
		c.SeriesType = "standard"
	}
}

func (c SonarrConfig) Enabled() bool {
	return strings.TrimSpace(c.URL) != "" || strings.TrimSpace(c.APIKey) != ""
}

func (c SonarrConfig) Validate() error {
	if !c.Enabled() {
		return nil
	}
	switch {
	case strings.TrimSpace(c.URL) == "":
		return fmt.Errorf("network.content.series.url must be set when series content is configured")
	case strings.TrimSpace(c.APIKey) == "":
		return fmt.Errorf("network.content.series.api_key must be set when series content is configured")
	case strings.TrimSpace(c.RootFolderPath) == "":
		return fmt.Errorf("network.content.series.root_folder_path must be set when series content is configured")
	case c.QualityProfileID <= 0:
		return fmt.Errorf("network.content.series.quality_profile_id must be set when series content is configured")
	case c.LanguageProfileID <= 0:
		return fmt.Errorf("network.content.series.language_profile_id must be set when series content is configured")
	case strings.TrimSpace(c.SeriesType) == "":
		return fmt.Errorf("network.content.series.series_type must not be empty")
	default:
		return nil
	}
}

func (c SonarrConfig) SeasonFolderValue() bool {
	return boolValue(c.SeasonFolder, true)
}

func (c SonarrConfig) SearchOnAddValue() bool {
	return boolValue(c.SearchOnAdd, true)
}

func newHTTPClient(rawURL, apiKey string) (*httpClient, error) {
	parsedURL, err := url.Parse(strings.TrimRight(strings.TrimSpace(rawURL), "/"))
	if err != nil {
		return nil, err
	}
	return &httpClient{
		baseURL:    parsedURL,
		apiKey:     apiKey,
		httpClient: http.DefaultClient,
	}, nil
}

func (c *httpClient) do(ctx context.Context, method, requestPath string, query url.Values, body any, dest any) error {
	endpoint := *c.baseURL
	endpoint.Path = path.Join(endpoint.Path, requestPath)
	if len(query) > 0 {
		endpoint.RawQuery = query.Encode()
	}

	var payload io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return err
		}
		payload = bytes.NewReader(data)
	}

	req, err := http.NewRequestWithContext(ctx, method, endpoint.String(), payload)
	if err != nil {
		return err
	}
	req.Header.Set("X-Api-Key", c.apiKey)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		data, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("%s %s returned %d: %s", method, endpoint.String(), resp.StatusCode, strings.TrimSpace(string(data)))
	}
	if dest == nil {
		return nil
	}
	return json.NewDecoder(resp.Body).Decode(dest)
}

func boolValue(value *bool, fallback bool) bool {
	if value == nil {
		return fallback
	}
	return *value
}

func containsFold(haystack, needle string) bool {
	return strings.Contains(strings.ToLower(haystack), strings.ToLower(strings.TrimSpace(needle)))
}

func FormatSearchResult(result SearchResult) string {
	if result.Year != 0 {
		return fmt.Sprintf("%s (%d)", result.Title, result.Year)
	}
	return result.Title
}
