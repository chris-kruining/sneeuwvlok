package subscriptions

import (
	"context"
	"fmt"

	"go.mau.fi/util/dbutil"
	"maunium.net/go/mautrix/id"

	"sneeuwvlok/packages/arrtrix/pkg/arr"
)

type Preference struct {
	ContentType arr.ContentType
	EventType   string
	Enabled     bool
}

type Repository struct {
	db       *dbutil.Database
	bridgeID string
}

func EnsureSchema(ctx context.Context, db *dbutil.Database) error {
	_, err := db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS arrtrix_subscription (
			bridge_id TEXT NOT NULL,
			user_mxid TEXT NOT NULL,
			content_type TEXT NOT NULL,
			event_type TEXT NOT NULL,
			enabled BOOLEAN NOT NULL,
			PRIMARY KEY (bridge_id, user_mxid, content_type, event_type)
		)
	`)
	return err
}

func NewRepository(db *dbutil.Database, bridgeID string) *Repository {
	return &Repository{db: db, bridgeID: bridgeID}
}

func (r *Repository) EnsureDefaults(ctx context.Context, userID id.UserID) error {
	var existing int
	if err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM arrtrix_subscription WHERE bridge_id=$1 AND user_mxid=$2`, r.bridgeID, userID.String()).Scan(&existing); err != nil {
		return err
	}
	if existing > 0 {
		return nil
	}

	for _, contentType := range arr.SupportedContentTypes() {
		for _, eventType := range arr.SupportedEventTypes(contentType) {
			if _, err := r.db.Exec(ctx, `
				INSERT INTO arrtrix_subscription (bridge_id, user_mxid, content_type, event_type, enabled)
				VALUES ($1, $2, $3, $4, TRUE)
			`, r.bridgeID, userID.String(), string(contentType), eventType); err != nil {
				return err
			}
		}
	}
	return nil
}

func (r *Repository) List(ctx context.Context, userID id.UserID) ([]Preference, error) {
	if err := r.EnsureDefaults(ctx, userID); err != nil {
		return nil, err
	}

	rows, err := r.db.Query(ctx, `
		SELECT content_type, event_type, enabled
		FROM arrtrix_subscription
		WHERE bridge_id=$1 AND user_mxid=$2
		ORDER BY content_type, event_type
	`, r.bridgeID, userID.String())
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var preferences []Preference
	for rows.Next() {
		var contentType string
		var preference Preference
		if err = rows.Scan(&contentType, &preference.EventType, &preference.Enabled); err != nil {
			return nil, err
		}
		preference.ContentType = arr.ContentType(contentType)
		preferences = append(preferences, preference)
	}
	if err = rows.Err(); err != nil {
		return nil, err
	}
	return preferences, nil
}

func (r *Repository) Set(ctx context.Context, userID id.UserID, contentType arr.ContentType, eventType string, enabled bool) error {
	if err := r.EnsureDefaults(ctx, userID); err != nil {
		return err
	}
	if _, err := r.db.Exec(ctx, `
		INSERT INTO arrtrix_subscription (bridge_id, user_mxid, content_type, event_type, enabled)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (bridge_id, user_mxid, content_type, event_type)
		DO UPDATE SET enabled=excluded.enabled
	`, r.bridgeID, userID.String(), string(contentType), eventType, enabled); err != nil {
		return err
	}
	return nil
}

func (r *Repository) SetAll(ctx context.Context, userID id.UserID, contentType arr.ContentType, enabled bool) error {
	if err := r.EnsureDefaults(ctx, userID); err != nil {
		return err
	}
	for _, eventType := range arr.SupportedEventTypes(contentType) {
		if err := r.Set(ctx, userID, contentType, eventType, enabled); err != nil {
			return err
		}
	}
	return nil
}

func (r *Repository) Allows(ctx context.Context, userID id.UserID, contentType arr.ContentType, eventType string) (bool, error) {
	if !arr.SupportsEventType(contentType, eventType) {
		return true, nil
	}
	if err := r.EnsureDefaults(ctx, userID); err != nil {
		return false, err
	}

	var enabled bool
	err := r.db.QueryRow(ctx, `
		SELECT enabled
		FROM arrtrix_subscription
		WHERE bridge_id=$1 AND user_mxid=$2 AND content_type=$3 AND event_type=$4
	`, r.bridgeID, userID.String(), string(contentType), eventType).Scan(&enabled)
	if err != nil {
		return false, fmt.Errorf("query subscription: %w", err)
	}
	return enabled, nil
}
