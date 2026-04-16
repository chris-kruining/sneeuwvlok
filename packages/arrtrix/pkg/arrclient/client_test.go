package arrclient

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestImageURLPrefersPosterAndResolvesRelativePath(t *testing.T) {
	baseURL, err := url.Parse("https://radarr.example")
	if err != nil {
		t.Fatalf("failed to parse base URL: %v", err)
	}

	client := &httpClient{baseURL: baseURL}
	imageURL := client.imageURL([]mediaImage{
		{CoverType: "fanart", URL: "/MediaCover/1/fanart.jpg"},
		{CoverType: "poster", URL: "/MediaCover/1/poster.jpg"},
	})
	if imageURL != "https://radarr.example/MediaCover/1/poster.jpg" {
		t.Fatalf("unexpected image URL %q", imageURL)
	}
}

func TestImageURLFallsBackToRemoteURL(t *testing.T) {
	baseURL, err := url.Parse("https://sonarr.example")
	if err != nil {
		t.Fatalf("failed to parse base URL: %v", err)
	}

	client := &httpClient{baseURL: baseURL}
	imageURL := client.imageURL([]mediaImage{
		{CoverType: "poster", RemoteURL: "https://images.example/poster.jpg"},
	})
	if imageURL != "https://images.example/poster.jpg" {
		t.Fatalf("unexpected remote image URL %q", imageURL)
	}
}

func TestFetchImageUsesAPIKeyForSameHost(t *testing.T) {
	headers := make(chan string, 1)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		headers <- r.Header.Get("X-Api-Key")
		w.Header().Set("Content-Type", "image/jpeg")
		_, _ = w.Write([]byte("jpeg-bytes"))
	}))
	defer server.Close()

	client, err := newHTTPClient(server.URL, "secret")
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	asset, err := client.FetchImage(context.Background(), ManagedItem{
		ID:       42,
		Title:    "Dune Part Two",
		ImageURL: server.URL + "/MediaCover/42/poster.jpg",
	})
	if err != nil {
		t.Fatalf("failed to fetch image: %v", err)
	}
	if asset == nil {
		t.Fatal("expected media asset")
	}
	if got := <-headers; got != "secret" {
		t.Fatalf("expected API key header, got %q", got)
	}
	if got := string(asset.Data); got != "jpeg-bytes" {
		t.Fatalf("unexpected media bytes %q", got)
	}
	if asset.MimeType != "image/jpeg" {
		t.Fatalf("unexpected mime type %q", asset.MimeType)
	}
	if !strings.HasPrefix(asset.FileName, "Dune-Part-Two-42") || !strings.HasSuffix(asset.FileName, ".jpg") {
		t.Fatalf("unexpected filename %q", asset.FileName)
	}
}
