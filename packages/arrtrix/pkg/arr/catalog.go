package arr

import (
	"fmt"
	"slices"
	"strings"
)

type ContentType string

const (
	ContentTypeMovies ContentType = "movies"
	ContentTypeSeries ContentType = "series"
)

var supportedContentTypes = []ContentType{
	ContentTypeMovies,
	ContentTypeSeries,
}

var supportedEvents = map[ContentType][]string{
	ContentTypeMovies: {"Test", "Grab", "Download", "Rename", "MovieFileDelete", "MovieDelete"},
	ContentTypeSeries: {"Test", "Grab", "Download", "Rename", "EpisodeFileDelete", "SeriesDelete"},
}

func SupportedContentTypes() []ContentType {
	return append([]ContentType(nil), supportedContentTypes...)
}

func SupportedEventTypes(contentType ContentType) []string {
	return append([]string(nil), supportedEvents[contentType]...)
}

func ParseContentType(value string) (ContentType, error) {
	contentType := ContentType(strings.ToLower(strings.TrimSpace(value)))
	if slices.Contains(supportedContentTypes, contentType) {
		return contentType, nil
	}
	return "", fmt.Errorf("unsupported content type %q (expected one of: %s)", value, Strings())
}

func ParseEventType(contentType ContentType, value string) (string, error) {
	value = strings.TrimSpace(value)
	if strings.EqualFold(value, "all") {
		return "all", nil
	}
	for _, eventType := range supportedEvents[contentType] {
		if strings.EqualFold(eventType, value) {
			return eventType, nil
		}
	}
	return "", fmt.Errorf("unsupported event type %q for %s", value, contentType)
}

func SupportsEventType(contentType ContentType, eventType string) bool {
	return slices.Contains(supportedEvents[contentType], strings.TrimSpace(eventType))
}

func (c ContentType) Label() string {
	switch c {
	case ContentTypeMovies:
		return "movies"
	case ContentTypeSeries:
		return "series"
	default:
		return string(c)
	}
}

func Strings() string {
	values := make([]string, 0, len(supportedContentTypes))
	for _, contentType := range supportedContentTypes {
		values = append(values, string(contentType))
	}
	return strings.Join(values, ", ")
}
