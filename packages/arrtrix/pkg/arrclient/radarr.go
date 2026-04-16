package arrclient

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"sneeuwvlok/packages/arrtrix/pkg/arr"
)

type RadarrClient struct {
	http   *httpClient
	config RadarrConfig
}

type radarrMovie struct {
	ID        int64  `json:"id"`
	Title     string `json:"title"`
	Year      int    `json:"year"`
	TMDBID    int64  `json:"tmdbId"`
	Overview  string `json:"overview"`
	Monitored bool   `json:"monitored"`
	Path      string `json:"path"`
}

func NewRadarrClient(config RadarrConfig) (*RadarrClient, error) {
	config.ApplyDefaults()
	if err := config.Validate(); err != nil {
		return nil, err
	}
	httpClient, err := newHTTPClient(config.URL, config.APIKey)
	if err != nil {
		return nil, err
	}
	return &RadarrClient{http: httpClient, config: config}, nil
}

func (c *RadarrClient) ContentType() arr.ContentType {
	return arr.ContentTypeMovies
}

func (c *RadarrClient) Search(ctx context.Context, query string) ([]SearchResult, error) {
	var response []radarrMovie
	if err := c.http.do(ctx, http.MethodGet, "/api/v3/movie/lookup", url.Values{"term": {strings.TrimSpace(query)}}, nil, &response); err != nil {
		return nil, err
	}

	results := make([]SearchResult, 0, len(response))
	for _, movie := range response {
		if movie.TMDBID == 0 {
			continue
		}
		results = append(results, SearchResult{
			LookupID: movie.TMDBID,
			Title:    movie.Title,
			Year:     movie.Year,
			Overview: movie.Overview,
		})
	}
	return results, nil
}

func (c *RadarrClient) List(ctx context.Context, query string) ([]ManagedItem, error) {
	var response []radarrMovie
	if err := c.http.do(ctx, http.MethodGet, "/api/v3/movie", nil, nil, &response); err != nil {
		return nil, err
	}

	items := make([]ManagedItem, 0, len(response))
	for _, movie := range response {
		if query != "" && !containsFold(movie.Title, query) && !containsFold(strconv.Itoa(movie.Year), query) {
			continue
		}
		items = append(items, ManagedItem{
			ID:        movie.ID,
			LookupID:  movie.TMDBID,
			Title:     movie.Title,
			Year:      movie.Year,
			Monitored: movie.Monitored,
			Path:      movie.Path,
		})
	}
	return items, nil
}

func (c *RadarrClient) Add(ctx context.Context, result SearchResult) (*ManagedItem, error) {
	payload := map[string]any{
		"title":               result.Title,
		"tmdbId":              result.LookupID,
		"year":                result.Year,
		"qualityProfileId":    c.config.QualityProfileID,
		"rootFolderPath":      c.config.RootFolderPath,
		"minimumAvailability": c.config.MinimumAvailability,
		"monitored":           true,
		"addOptions": map[string]any{
			"searchForMovie": c.config.SearchOnAddValue(),
		},
	}

	var response radarrMovie
	if err := c.http.do(ctx, http.MethodPost, "/api/v3/movie", nil, payload, &response); err != nil {
		return nil, err
	}
	item := ManagedItem{
		ID:        response.ID,
		LookupID:  response.TMDBID,
		Title:     response.Title,
		Year:      response.Year,
		Monitored: response.Monitored,
		Path:      response.Path,
	}
	return &item, nil
}

func (c *RadarrClient) SetMonitored(ctx context.Context, id int64, monitored bool) (*ManagedItem, error) {
	var movie map[string]any
	endpoint := "/api/v3/movie/" + strconv.FormatInt(id, 10)
	if err := c.http.do(ctx, http.MethodGet, endpoint, nil, nil, &movie); err != nil {
		return nil, err
	}
	movie["monitored"] = monitored

	var response radarrMovie
	if err := c.http.do(ctx, http.MethodPut, endpoint, nil, movie, &response); err != nil {
		return nil, err
	}
	item := ManagedItem{
		ID:        response.ID,
		LookupID:  response.TMDBID,
		Title:     response.Title,
		Year:      response.Year,
		Monitored: response.Monitored,
		Path:      response.Path,
	}
	return &item, nil
}

func (c *RadarrClient) Delete(ctx context.Context, id int64) error {
	return c.http.do(ctx, http.MethodDelete, "/api/v3/movie/"+strconv.FormatInt(id, 10), url.Values{
		"deleteFiles":        {"false"},
		"addImportExclusion": {"false"},
	}, nil, nil)
}

func PickSingleResult(results []SearchResult, query string) (SearchResult, error) {
	switch len(results) {
	case 0:
		return SearchResult{}, fmt.Errorf("no matching result found for %q", query)
	case 1:
		return results[0], nil
	default:
		normalized := strings.TrimSpace(strings.ToLower(query))
		for _, result := range results {
			title := strings.ToLower(FormatSearchResult(result))
			if title == normalized {
				return result, nil
			}
		}
		return SearchResult{}, fmt.Errorf("multiple results matched %q", query)
	}
}
