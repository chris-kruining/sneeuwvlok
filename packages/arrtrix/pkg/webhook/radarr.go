package webhook

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/event"
	"maunium.net/go/mautrix/format"
	"maunium.net/go/mautrix/id"
)

const (
	defaultRadarrWebhookPath = "/_arrtrix/webhooks/radarr"
	radarrSecretHeader       = "X-Arrtrix-Webhook-Secret"
)

var (
	ErrNoManagementRoom        = errors.New("no management room configured")
	ErrAmbiguousManagementRoom = errors.New("multiple management rooms configured")
)

type RadarrConfig struct {
	Enabled bool   `yaml:"enabled"`
	Path    string `yaml:"path"`
	Secret  string `yaml:"secret"`
}

type radarrPayload struct {
	EventType string           `json:"eventType"`
	Movie     *radarrMovie     `json:"movie"`
	MovieFile *radarrMovieFile `json:"movieFile"`
	IsUpgrade bool             `json:"isUpgrade"`
}

type radarrMovie struct {
	Title  string `json:"title"`
	Year   int    `json:"year"`
	ImdbID string `json:"imdbId"`
	TmdbID int    `json:"tmdbId"`
	Path   string `json:"path"`
}

type radarrMovieFile struct {
	Quality      string `json:"quality"`
	RelativePath string `json:"relativePath"`
	SceneName    string `json:"sceneName"`
	ReleaseGroup string `json:"releaseGroup"`
}

type roomResolver interface {
	ResolveManagementRoom(context.Context) (id.RoomID, error)
}

type noticeSender interface {
	SendNotice(context.Context, id.RoomID, string) error
}

type RadarrHandler struct {
	config   RadarrConfig
	resolver roomResolver
	sender   noticeSender
}

func (c *RadarrConfig) ApplyDefaults() {
	if c.Path == "" {
		c.Path = defaultRadarrWebhookPath
	}
}

func (c *RadarrConfig) Validate() error {
	c.ApplyDefaults()
	if !c.Enabled {
		return nil
	}
	if !strings.HasPrefix(c.Path, "/") {
		return fmt.Errorf("network.webhooks.radarr.path must start with /")
	}
	if strings.TrimSpace(c.Secret) == "" {
		return fmt.Errorf("network.webhooks.radarr.secret must be set when the webhook is enabled")
	}
	return nil
}

func MountRadarr(router *http.ServeMux, bridge *bridgev2.Bridge, cfg RadarrConfig) error {
	cfg.ApplyDefaults()
	if !cfg.Enabled {
		return nil
	}
	if err := cfg.Validate(); err != nil {
		return err
	}

	handler := &RadarrHandler{
		config:   cfg,
		resolver: bridgeRoomResolver{bridge: bridge},
		sender:   bridgeNoticeSender{bridge: bridge},
	}
	router.Handle(fmt.Sprintf("POST %s", cfg.Path), handler)
	return nil
}

func (h *RadarrHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if !authorized(r, h.config.Secret) {
		http.Error(w, "invalid webhook secret", http.StatusUnauthorized)
		return
	}

	var payload radarrPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid webhook payload", http.StatusBadRequest)
		return
	}
	if strings.TrimSpace(payload.EventType) == "" {
		http.Error(w, "missing eventType", http.StatusBadRequest)
		return
	}

	roomID, err := h.resolver.ResolveManagementRoom(r.Context())
	if err != nil {
		status := http.StatusInternalServerError
		if errors.Is(err, ErrNoManagementRoom) || errors.Is(err, ErrAmbiguousManagementRoom) {
			status = http.StatusConflict
		}
		http.Error(w, err.Error(), status)
		return
	}

	if err = h.sender.SendNotice(r.Context(), roomID, renderRadarrNotice(payload)); err != nil {
		http.Error(w, "failed to deliver webhook", http.StatusBadGateway)
		return
	}

	w.WriteHeader(http.StatusAccepted)
}

type bridgeRoomResolver struct {
	bridge *bridgev2.Bridge
}

func (r bridgeRoomResolver) ResolveManagementRoom(ctx context.Context) (id.RoomID, error) {
	rows, err := r.bridge.DB.Query(ctx, `SELECT mxid, management_room FROM "user" WHERE bridge_id=$1 AND management_room IS NOT NULL AND management_room <> ''`, r.bridge.ID)
	if err != nil {
		return "", fmt.Errorf("failed to query management rooms: %w", err)
	}
	defer rows.Close()

	var roomID id.RoomID
	var owners []id.UserID
	for rows.Next() {
		var mxid, managementRoom string
		if err = rows.Scan(&mxid, &managementRoom); err != nil {
			return "", fmt.Errorf("failed to scan management room: %w", err)
		}
		owners = append(owners, id.UserID(mxid))
		if roomID == "" {
			roomID = id.RoomID(managementRoom)
		}
	}
	if err = rows.Err(); err != nil {
		return "", fmt.Errorf("failed to iterate management rooms: %w", err)
	}
	switch len(owners) {
	case 0:
		return "", ErrNoManagementRoom
	case 1:
		return roomID, nil
	default:
		return "", fmt.Errorf("%w: %s", ErrAmbiguousManagementRoom, strings.Join(convertUserIDs(owners), ", "))
	}
}

type bridgeNoticeSender struct {
	bridge *bridgev2.Bridge
}

func (s bridgeNoticeSender) SendNotice(ctx context.Context, roomID id.RoomID, markdown string) error {
	if err := s.bridge.Bot.EnsureJoined(ctx, roomID); err != nil {
		return err
	}
	content := format.RenderMarkdown(markdown, true, false)
	_, err := s.bridge.Bot.SendMessage(ctx, roomID, event.EventMessage, &event.Content{Parsed: &content}, nil)
	return err
}

func authorized(r *http.Request, secret string) bool {
	if secret == "" {
		return true
	}
	if r.Header.Get(radarrSecretHeader) == secret {
		return true
	}
	if bearer := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "); bearer == secret && bearer != r.Header.Get("Authorization") {
		return true
	}
	return r.URL.Query().Get("secret") == secret
}

func renderRadarrNotice(payload radarrPayload) string {
	title := "Radarr"
	if payload.Movie != nil {
		title = payload.Movie.Title
		if payload.Movie.Year != 0 {
			title = fmt.Sprintf("%s (%d)", title, payload.Movie.Year)
		}
	}

	lines := []string{fmt.Sprintf("**Radarr %s**", payload.EventType)}
	if title != "Radarr" {
		lines = append(lines, fmt.Sprintf("Movie: %s", title))
	}
	if payload.MovieFile != nil && payload.MovieFile.Quality != "" {
		lines = append(lines, fmt.Sprintf("Quality: %s", payload.MovieFile.Quality))
	}
	if payload.MovieFile != nil && payload.MovieFile.RelativePath != "" {
		lines = append(lines, fmt.Sprintf("File: `%s`", payload.MovieFile.RelativePath))
	}
	if payload.EventType == "Download" {
		lines = append(lines, fmt.Sprintf("Upgrade: %t", payload.IsUpgrade))
	}
	if payload.Movie != nil && payload.Movie.ImdbID != "" {
		lines = append(lines, fmt.Sprintf("IMDb: `%s`", payload.Movie.ImdbID))
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
var _ http.Handler = (*RadarrHandler)(nil)
