package webhook

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/event"
	"maunium.net/go/mautrix/format"
	"maunium.net/go/mautrix/id"

	"sneeuwvlok/packages/arrtrix/pkg/arr"
	"sneeuwvlok/packages/arrtrix/pkg/observability"
)

const ArrWebhookPath = "/_arrtrix/webhook"

var (
	ErrNoManagementRoom        = errors.New("no management room configured")
	ErrAmbiguousManagementRoom = errors.New("multiple management rooms configured")
)

type payload struct {
	EventType   string       `json:"eventType"`
	Movie       *movie       `json:"movie"`
	MovieFile   *movieFile   `json:"movieFile"`
	Series      *series      `json:"series"`
	Episodes    []episode    `json:"episodes"`
	EpisodeFile *episodeFile `json:"episodeFile"`
	IsUpgrade   bool         `json:"isUpgrade"`
}

type movie struct {
	Title  string `json:"title"`
	Year   int    `json:"year"`
	ImdbID string `json:"imdbId"`
	TmdbID int    `json:"tmdbId"`
	Path   string `json:"path"`
}

type movieFile struct {
	Quality      string `json:"quality"`
	RelativePath string `json:"relativePath"`
	SceneName    string `json:"sceneName"`
	ReleaseGroup string `json:"releaseGroup"`
}

type series struct {
	Title string `json:"title"`
	Year  int    `json:"year"`
	Path  string `json:"path"`
}

type episode struct {
	SeasonNumber  int    `json:"seasonNumber"`
	EpisodeNumber int    `json:"episodeNumber"`
	Title         string `json:"title"`
}

type episodeFile struct {
	Quality      string `json:"quality"`
	RelativePath string `json:"relativePath"`
	SceneName    string `json:"sceneName"`
}

type managementTarget struct {
	UserID id.UserID
	RoomID id.RoomID
}

type roomResolver interface {
	ResolveManagementRoom(context.Context) (managementTarget, error)
}

type noticeSender interface {
	SendNotice(context.Context, id.RoomID, string) error
}

type SubscriptionFilter interface {
	Allows(context.Context, id.UserID, arr.ContentType, string) (bool, error)
}

type ArrHandler struct {
	resolver      roomResolver
	sender        noticeSender
	subscriptions SubscriptionFilter
}

func MountArr(router *http.ServeMux, bridge *bridgev2.Bridge, subscriptions SubscriptionFilter) error {
	if bridge == nil {
		return fmt.Errorf("bridge is not initialized")
	}
	handler := &ArrHandler{
		resolver:      bridgeRoomResolver{bridge: bridge},
		sender:        bridgeNoticeSender{bridge: bridge},
		subscriptions: subscriptions,
	}
	router.Handle(fmt.Sprintf("POST %s", ArrWebhookPath), handler)
	return nil
}

func (h *ArrHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	ctx, span := observability.StartSpan(r.Context(), "arrtrix.webhook.handle", trace.WithSpanKind(trace.SpanKindServer))
	defer span.End()

	statusCode := http.StatusAccepted
	outcome := "ok"
	eventType := ""
	defer func() {
		observability.RecordWebhook(ctx, eventType, outcome, statusCode, time.Since(start))
	}()

	var body payload
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		statusCode = http.StatusBadRequest
		outcome = "invalid_payload"
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, "invalid webhook payload", http.StatusBadRequest)
		return
	}
	if strings.TrimSpace(body.EventType) == "" {
		statusCode = http.StatusBadRequest
		outcome = "missing_event_type"
		span.SetStatus(codes.Error, "missing eventType")
		http.Error(w, "missing eventType", http.StatusBadRequest)
		return
	}
	eventType = body.EventType
	span.SetAttributes(
		attribute.String("arrtrix.webhook.event_type", body.EventType),
		attribute.String("http.method", r.Method),
		attribute.String("http.route", ArrWebhookPath),
	)

	target, err := h.resolver.ResolveManagementRoom(ctx)
	if err != nil {
		statusCode = http.StatusInternalServerError
		outcome = "resolve_failed"
		if errors.Is(err, ErrNoManagementRoom) || errors.Is(err, ErrAmbiguousManagementRoom) {
			statusCode = http.StatusConflict
			outcome = "routing_conflict"
		}
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), statusCode)
		return
	}

	contentType, ok := body.ContentType()
	if ok && h.subscriptions != nil {
		allowed, filterErr := h.subscriptions.Allows(ctx, target.UserID, contentType, body.EventType)
		if filterErr != nil {
			statusCode = http.StatusInternalServerError
			outcome = "subscription_check_failed"
			span.RecordError(filterErr)
			span.SetStatus(codes.Error, filterErr.Error())
			http.Error(w, "failed to evaluate subscriptions", statusCode)
			return
		}
		if !allowed {
			outcome = "filtered"
			span.SetStatus(codes.Ok, "filtered")
			w.WriteHeader(statusCode)
			return
		}
	}

	if err = h.sender.SendNotice(ctx, target.RoomID, renderNotice(body)); err != nil {
		statusCode = http.StatusBadGateway
		outcome = "delivery_failed"
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, "failed to deliver webhook", http.StatusBadGateway)
		return
	}

	span.SetStatus(codes.Ok, "")
	w.WriteHeader(statusCode)
}

type bridgeRoomResolver struct {
	bridge *bridgev2.Bridge
}

func (r bridgeRoomResolver) ResolveManagementRoom(ctx context.Context) (managementTarget, error) {
	ctx, span := observability.StartSpan(ctx, "arrtrix.webhook.resolve_management_room")
	defer span.End()

	rows, err := r.bridge.DB.Query(ctx, `SELECT mxid, management_room FROM "user" WHERE bridge_id=$1 AND management_room IS NOT NULL AND management_room <> ''`, r.bridge.ID)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return managementTarget{}, fmt.Errorf("failed to query management rooms: %w", err)
	}
	defer rows.Close()

	var target managementTarget
	var owners []id.UserID
	for rows.Next() {
		var mxid, managementRoom string
		if err = rows.Scan(&mxid, &managementRoom); err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
			return managementTarget{}, fmt.Errorf("failed to scan management room: %w", err)
		}
		owners = append(owners, id.UserID(mxid))
		if target.RoomID == "" {
			target = managementTarget{
				UserID: id.UserID(mxid),
				RoomID: id.RoomID(managementRoom),
			}
		}
	}
	if err = rows.Err(); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return managementTarget{}, fmt.Errorf("failed to iterate management rooms: %w", err)
	}

	switch len(owners) {
	case 0:
		span.SetStatus(codes.Error, ErrNoManagementRoom.Error())
		return managementTarget{}, ErrNoManagementRoom
	case 1:
		span.SetAttributes(attribute.Int("arrtrix.management_room.count", 1))
		span.SetStatus(codes.Ok, "")
		return target, nil
	default:
		span.SetAttributes(attribute.Int("arrtrix.management_room.count", len(owners)))
		span.SetStatus(codes.Error, ErrAmbiguousManagementRoom.Error())
		return managementTarget{}, fmt.Errorf("%w: %s", ErrAmbiguousManagementRoom, strings.Join(convertUserIDs(owners), ", "))
	}
}

type bridgeNoticeSender struct {
	bridge *bridgev2.Bridge
}

func (s bridgeNoticeSender) SendNotice(ctx context.Context, roomID id.RoomID, markdown string) error {
	ctx, span := observability.StartSpan(ctx, "arrtrix.webhook.send_notice")
	defer span.End()
	span.SetAttributes(attribute.String("matrix.room_id", roomID.String()))

	if err := s.bridge.Bot.EnsureJoined(ctx, roomID); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return err
	}
	content := format.RenderMarkdown(markdown, true, false)
	_, err := s.bridge.Bot.SendMessage(ctx, roomID, event.EventMessage, &event.Content{Parsed: &content}, nil)
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return err
	}
	span.SetStatus(codes.Ok, "")
	return err
}

func renderNotice(body payload) string {
	lines := []string{fmt.Sprintf("**Arr %s**", body.EventType)}

	switch contentType, ok := body.ContentType(); {
	case ok && contentType == arr.ContentTypeMovies:
		title := body.Movie.Title
		if body.Movie.Year != 0 {
			title = fmt.Sprintf("%s (%d)", title, body.Movie.Year)
		}
		lines = append(lines, fmt.Sprintf("Movie: %s", title))
		if body.MovieFile != nil && body.MovieFile.Quality != "" {
			lines = append(lines, fmt.Sprintf("Quality: %s", body.MovieFile.Quality))
		}
		if body.MovieFile != nil && body.MovieFile.RelativePath != "" {
			lines = append(lines, fmt.Sprintf("File: `%s`", body.MovieFile.RelativePath))
		}
		if body.EventType == "Download" {
			lines = append(lines, fmt.Sprintf("Upgrade: %t", body.IsUpgrade))
		}
		if body.Movie.ImdbID != "" {
			lines = append(lines, fmt.Sprintf("IMDb: `%s`", body.Movie.ImdbID))
		}
	case ok && contentType == arr.ContentTypeSeries:
		title := body.Series.Title
		if body.Series.Year != 0 {
			title = fmt.Sprintf("%s (%d)", title, body.Series.Year)
		}
		lines = append(lines, fmt.Sprintf("Series: %s", title))
		if len(body.Episodes) > 0 {
			lines = append(lines, fmt.Sprintf("Episodes: %s", renderEpisodes(body.Episodes)))
		}
		if body.EpisodeFile != nil && body.EpisodeFile.Quality != "" {
			lines = append(lines, fmt.Sprintf("Quality: %s", body.EpisodeFile.Quality))
		}
		if body.EpisodeFile != nil && body.EpisodeFile.RelativePath != "" {
			lines = append(lines, fmt.Sprintf("File: `%s`", body.EpisodeFile.RelativePath))
		}
	default:
		if body.EventType != "Test" {
			lines = append(lines, "Payload received.")
		}
	}

	return strings.Join(lines, "\n")
}

func convertUserIDs(users []id.UserID) []string {
	out := make([]string, len(users))
	for i, user := range users {
		out[i] = string(user)
	}
	return out
}

var _ roomResolver = bridgeRoomResolver{}
var _ noticeSender = bridgeNoticeSender{}
var _ http.Handler = (*ArrHandler)(nil)

func (p payload) ContentType() (arr.ContentType, bool) {
	switch {
	case p.Movie != nil:
		return arr.ContentTypeMovies, true
	case p.Series != nil:
		return arr.ContentTypeSeries, true
	default:
		return "", false
	}
}

func renderEpisodes(episodes []episode) string {
	parts := make([]string, 0, len(episodes))
	for _, item := range episodes {
		if item.Title != "" {
			parts = append(parts, fmt.Sprintf("S%02dE%02d %s", item.SeasonNumber, item.EpisodeNumber, item.Title))
			continue
		}
		parts = append(parts, fmt.Sprintf("S%02dE%02d", item.SeasonNumber, item.EpisodeNumber))
	}
	return strings.Join(parts, ", ")
}
