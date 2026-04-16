package arr

import "testing"

func TestParseContentType(t *testing.T) {
	contentType, err := ParseContentType("Movies")
	if err != nil {
		t.Fatalf("ParseContentType returned error: %v", err)
	}
	if contentType != ContentTypeMovies {
		t.Fatalf("expected movies content type, got %q", contentType)
	}
}

func TestParseEventType(t *testing.T) {
	eventType, err := ParseEventType(ContentTypeSeries, "download")
	if err != nil {
		t.Fatalf("ParseEventType returned error: %v", err)
	}
	if eventType != "Download" {
		t.Fatalf("expected Download event type, got %q", eventType)
	}
}
