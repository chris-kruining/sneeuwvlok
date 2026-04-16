package webhook

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"maunium.net/go/mautrix/id"

	"sneeuwvlok/packages/arrtrix/pkg/arr"
)

type stubRoomResolver struct {
	target managementTarget
	err    error
}

func (s stubRoomResolver) ResolveManagementRoom(context.Context) (managementTarget, error) {
	return s.target, s.err
}

type stubNoticeSender struct {
	roomID  id.RoomID
	message string
	err     error
}

type stubSubscriptionFilter struct {
	allowed bool
	err     error
}

func (s *stubNoticeSender) SendNotice(_ context.Context, roomID id.RoomID, message string) error {
	s.roomID = roomID
	s.message = message
	return s.err
}

func (s stubSubscriptionFilter) Allows(context.Context, id.UserID, arr.ContentType, string) (bool, error) {
	return s.allowed, s.err
}

func TestMountArrRequiresBridge(t *testing.T) {
	router := http.NewServeMux()
	if err := MountArr(router, nil, nil); err == nil {
		t.Fatal("expected nil bridge to fail")
	}
}

func TestArrHandlerDeliversNotice(t *testing.T) {
	sender := &stubNoticeSender{}
	handler := &ArrHandler{
		resolver: stubRoomResolver{target: managementTarget{UserID: "@user:test", RoomID: "!room:test"}},
		sender:   sender,
	}

	req := httptest.NewRequest(http.MethodPost, ArrWebhookPath, strings.NewReader(`{"eventType":"Download","movie":{"title":"Dune","year":2021,"imdbId":"tt1160419"},"movieFile":{"quality":"1080p","relativePath":"Dune (2021)/Dune.mkv"},"isUpgrade":false}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected accepted status, got %d", rec.Code)
	}
	if sender.roomID != "!room:test" {
		t.Fatalf("expected notice sent to management room, got %q", sender.roomID)
	}
	if !strings.Contains(sender.message, "**Arr Download**") || !strings.Contains(sender.message, "Dune (2021)") {
		t.Fatalf("unexpected message: %s", sender.message)
	}
}

func TestArrHandlerReportsAmbiguousManagementRoom(t *testing.T) {
	handler := &ArrHandler{
		resolver: stubRoomResolver{err: ErrAmbiguousManagementRoom},
		sender:   &stubNoticeSender{},
	}

	req := httptest.NewRequest(http.MethodPost, ArrWebhookPath, strings.NewReader(`{"eventType":"Test"}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected conflict status, got %d", rec.Code)
	}
}

func TestRenderNoticeForTestEvent(t *testing.T) {
	msg := renderNotice(payload{EventType: "Test"})
	if strings.TrimSpace(msg) != "**Arr Test**" {
		t.Fatalf("unexpected test-event message: %q", msg)
	}
}

func TestArrHandlerReturnsBadGatewayOnSendFailure(t *testing.T) {
	handler := &ArrHandler{
		resolver: stubRoomResolver{target: managementTarget{UserID: "@user:test", RoomID: "!room:test"}},
		sender:   &stubNoticeSender{err: errors.New("send failed")},
	}

	req := httptest.NewRequest(http.MethodPost, ArrWebhookPath, strings.NewReader(`{"eventType":"Test"}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadGateway {
		t.Fatalf("expected bad gateway status, got %d", rec.Code)
	}
}

func TestArrHandlerRejectsMissingEventType(t *testing.T) {
	handler := &ArrHandler{
		resolver: stubRoomResolver{target: managementTarget{UserID: "@user:test", RoomID: "!room:test"}},
		sender:   &stubNoticeSender{},
	}

	req := httptest.NewRequest(http.MethodPost, ArrWebhookPath, strings.NewReader(`{"movie":{"title":"Dune"}}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected bad request status, got %d", rec.Code)
	}
}

func TestArrHandlerFiltersDisabledSubscriptions(t *testing.T) {
	sender := &stubNoticeSender{}
	handler := &ArrHandler{
		resolver:      stubRoomResolver{target: managementTarget{UserID: "@user:test", RoomID: "!room:test"}},
		sender:        sender,
		subscriptions: stubSubscriptionFilter{allowed: false},
	}

	req := httptest.NewRequest(http.MethodPost, ArrWebhookPath, strings.NewReader(`{"eventType":"Download","movie":{"title":"Dune","year":2021}}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected accepted status, got %d", rec.Code)
	}
	if sender.roomID != "" {
		t.Fatalf("expected no notice to be sent, got room %q", sender.roomID)
	}
}
