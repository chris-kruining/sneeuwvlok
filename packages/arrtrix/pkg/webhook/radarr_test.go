package webhook

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"maunium.net/go/mautrix/id"
)

type stubRoomResolver struct {
	roomID id.RoomID
	err    error
}

func (s stubRoomResolver) ResolveManagementRoom(context.Context) (id.RoomID, error) {
	return s.roomID, s.err
}

type stubNoticeSender struct {
	roomID  id.RoomID
	message string
	err     error
}

func (s *stubNoticeSender) SendNotice(_ context.Context, roomID id.RoomID, message string) error {
	s.roomID = roomID
	s.message = message
	return s.err
}

func TestRadarrConfigDefaultsAndValidation(t *testing.T) {
	cfg := RadarrConfig{Enabled: true, Secret: "secret"}
	cfg.ApplyDefaults()
	if cfg.Path != defaultRadarrWebhookPath {
		t.Fatalf("expected default path %q, got %q", defaultRadarrWebhookPath, cfg.Path)
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected config to validate, got %v", err)
	}
}

func TestRadarrConfigRequiresSecretWhenEnabled(t *testing.T) {
	cfg := RadarrConfig{Enabled: true}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected missing secret to fail validation")
	}
}

func TestRadarrHandlerRejectsUnauthorizedRequests(t *testing.T) {
	handler := &RadarrHandler{
		config:   RadarrConfig{Enabled: true, Secret: "secret"},
		resolver: stubRoomResolver{roomID: "!room:test"},
		sender:   &stubNoticeSender{},
	}

	req := httptest.NewRequest(http.MethodPost, defaultRadarrWebhookPath, strings.NewReader(`{"eventType":"Test"}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected unauthorized status, got %d", rec.Code)
	}
}

func TestRadarrHandlerDeliversNotice(t *testing.T) {
	sender := &stubNoticeSender{}
	handler := &RadarrHandler{
		config:   RadarrConfig{Enabled: true, Secret: "secret"},
		resolver: stubRoomResolver{roomID: "!room:test"},
		sender:   sender,
	}

	req := httptest.NewRequest(http.MethodPost, defaultRadarrWebhookPath+"?secret=secret", strings.NewReader(`{"eventType":"Download","movie":{"title":"Dune","year":2021,"imdbId":"tt1160419"},"movieFile":{"quality":"1080p","relativePath":"Dune (2021)/Dune.mkv"},"isUpgrade":false}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected accepted status, got %d", rec.Code)
	}
	if sender.roomID != "!room:test" {
		t.Fatalf("expected notice sent to management room, got %q", sender.roomID)
	}
	if !strings.Contains(sender.message, "**Radarr Download**") || !strings.Contains(sender.message, "Dune (2021)") {
		t.Fatalf("unexpected message: %s", sender.message)
	}
}

func TestRadarrHandlerReportsAmbiguousManagementRoom(t *testing.T) {
	handler := &RadarrHandler{
		config:   RadarrConfig{Enabled: true, Secret: "secret"},
		resolver: stubRoomResolver{err: ErrAmbiguousManagementRoom},
		sender:   &stubNoticeSender{},
	}

	req := httptest.NewRequest(http.MethodPost, defaultRadarrWebhookPath, strings.NewReader(`{"eventType":"Test"}`))
	req.Header.Set(radarrSecretHeader, "secret")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected conflict status, got %d", rec.Code)
	}
}

func TestRenderRadarrNoticeForTestEvent(t *testing.T) {
	msg := renderRadarrNotice(radarrPayload{EventType: "Test"})
	if strings.TrimSpace(msg) != "**Radarr Test**" {
		t.Fatalf("unexpected test-event message: %q", msg)
	}
}

func TestRadarrHandlerReturnsBadGatewayOnSendFailure(t *testing.T) {
	handler := &RadarrHandler{
		config:   RadarrConfig{Enabled: true, Secret: "secret"},
		resolver: stubRoomResolver{roomID: "!room:test"},
		sender:   &stubNoticeSender{err: errors.New("send failed")},
	}

	req := httptest.NewRequest(http.MethodPost, defaultRadarrWebhookPath, strings.NewReader(`{"eventType":"Test"}`))
	req.Header.Set(radarrSecretHeader, "secret")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadGateway {
		t.Fatalf("expected bad gateway status, got %d", rec.Code)
	}
}
