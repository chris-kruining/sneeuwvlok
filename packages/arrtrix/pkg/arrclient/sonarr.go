package arrclient

import (
	"context"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"sneeuwvlok/packages/arrtrix/pkg/arr"
)

type SonarrClient struct {
	http   *httpClient
	config SonarrConfig
}

type sonarrSeries struct {
	ID        int64  `json:"id"`
	Title     string `json:"title"`
	Year      int    `json:"year"`
	TVDBID    int64  `json:"tvdbId"`
	Overview  string `json:"overview"`
	Monitored bool   `json:"monitored"`
	Path      string `json:"path"`
}

func NewSonarrClient(config SonarrConfig) (*SonarrClient, error) {
	config.ApplyDefaults()
	if err := config.Validate(); err != nil {
		return nil, err
	}
	httpClient, err := newHTTPClient(config.URL, config.APIKey)
	if err != nil {
		return nil, err
	}
	return &SonarrClient{http: httpClient, config: config}, nil
}

func (c *SonarrClient) ContentType() arr.ContentType {
	return arr.ContentTypeSeries
}

func (c *SonarrClient) Search(ctx context.Context, query string) ([]SearchResult, error) {
	var response []sonarrSeries
	if err := c.http.do(ctx, http.MethodGet, "/api/v3/series/lookup", url.Values{"term": {strings.TrimSpace(query)}}, nil, &response); err != nil {
		return nil, err
	}

	results := make([]SearchResult, 0, len(response))
	for _, series := range response {
		if series.TVDBID == 0 {
			continue
		}
		results = append(results, SearchResult{
			LookupID: series.TVDBID,
			Title:    series.Title,
			Year:     series.Year,
			Overview: series.Overview,
		})
	}
	return results, nil
}

func (c *SonarrClient) List(ctx context.Context, query string) ([]ManagedItem, error) {
	var response []sonarrSeries
	if err := c.http.do(ctx, http.MethodGet, "/api/v3/series", nil, nil, &response); err != nil {
		return nil, err
	}

	items := make([]ManagedItem, 0, len(response))
	for _, series := range response {
		if query != "" && !containsFold(series.Title, query) && !containsFold(strconv.Itoa(series.Year), query) {
			continue
		}
		items = append(items, ManagedItem{
			ID:        series.ID,
			LookupID:  series.TVDBID,
			Title:     series.Title,
			Year:      series.Year,
			Monitored: series.Monitored,
			Path:      series.Path,
		})
	}
	return items, nil
}

func (c *SonarrClient) Add(ctx context.Context, result SearchResult) (*ManagedItem, error) {
	payload := map[string]any{
		"title":             result.Title,
		"tvdbId":            result.LookupID,
		"qualityProfileId":  c.config.QualityProfileID,
		"languageProfileId": c.config.LanguageProfileID,
		"rootFolderPath":    c.config.RootFolderPath,
		"seasonFolder":      c.config.SeasonFolderValue(),
		"monitored":         true,
		"seriesType":        c.config.SeriesType,
		"addOptions": map[string]any{
			"searchForMissingEpisodes": c.config.SearchOnAddValue(),
		},
	}
	if result.Year != 0 {
		payload["year"] = result.Year
	}

	var response sonarrSeries
	if err := c.http.do(ctx, http.MethodPost, "/api/v3/series", nil, payload, &response); err != nil {
		return nil, err
	}
	item := ManagedItem{
		ID:        response.ID,
		LookupID:  response.TVDBID,
		Title:     response.Title,
		Year:      response.Year,
		Monitored: response.Monitored,
		Path:      response.Path,
	}
	return &item, nil
}

func (c *SonarrClient) SetMonitored(ctx context.Context, id int64, monitored bool) (*ManagedItem, error) {
	var series map[string]any
	endpoint := "/api/v3/series/" + strconv.FormatInt(id, 10)
	if err := c.http.do(ctx, http.MethodGet, endpoint, nil, nil, &series); err != nil {
		return nil, err
	}
	series["monitored"] = monitored

	var response sonarrSeries
	if err := c.http.do(ctx, http.MethodPut, endpoint, nil, series, &response); err != nil {
		return nil, err
	}
	item := ManagedItem{
		ID:        response.ID,
		LookupID:  response.TVDBID,
		Title:     response.Title,
		Year:      response.Year,
		Monitored: response.Monitored,
		Path:      response.Path,
	}
	return &item, nil
}

func (c *SonarrClient) Delete(ctx context.Context, id int64) error {
	return c.http.do(ctx, http.MethodDelete, "/api/v3/series/"+strconv.FormatInt(id, 10), url.Values{
		"deleteFiles":            {"false"},
		"addImportListExclusion": {"false"},
	}, nil, nil)
}
