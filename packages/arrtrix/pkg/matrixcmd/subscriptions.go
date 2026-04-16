package matrixcmd

import (
	"context"
	"fmt"
	"strings"

	"maunium.net/go/mautrix/id"

	"sneeuwvlok/packages/arrtrix/pkg/arr"
	"sneeuwvlok/packages/arrtrix/pkg/subscriptions"
)

func NewSubscriptionsHandler() Handler {
	return NewHandler(Meta{
		Name:        "subscriptions",
		Aliases:     []string{"subscription", "notify"},
		Description: "Manage notification subscriptions by content type and event type.",
		Usage:       "<list|enable|disable> [movies|series] [event-type|all]",
	}, func(ctx *Context) {
		repo := contentSubscriptions(ctx)
		if repo == nil {
			ctx.Reply("Subscription storage is not available.")
			return
		}
		if len(ctx.Args) == 0 || strings.EqualFold(ctx.Args[0], "list") {
			handleSubscriptionList(ctx, repo)
			return
		}
		if len(ctx.Args) < 3 {
			ctx.Reply("Usage: `subscriptions <enable|disable> <movies|series> <event-type|all>`")
			return
		}

		contentType, err := arr.ParseContentType(ctx.Args[1])
		if err != nil {
			ctx.Reply(err.Error())
			return
		}
		eventType, err := arr.ParseEventType(contentType, ctx.Args[2])
		if err != nil {
			ctx.Reply(err.Error())
			return
		}

		switch strings.ToLower(ctx.Args[0]) {
		case "enable":
			handleSubscriptionSet(ctx, repo, contentType, eventType, true)
		case "disable":
			handleSubscriptionSet(ctx, repo, contentType, eventType, false)
		default:
			ctx.Reply("Unknown subscriptions subcommand `%s`.", ctx.Args[0])
		}
	})
}

func handleSubscriptionList(ctx *Context, repo subscriptionRepo) {
	preferences, err := repo.List(ctx.Ctx, ctx.User.MXID)
	if err != nil {
		ctx.Reply("Failed to load subscriptions: %v", err)
		return
	}

	var builder strings.Builder
	builder.WriteString("Current notification subscriptions:\n")
	for _, contentType := range arr.SupportedContentTypes() {
		builder.WriteString(fmt.Sprintf("\n**%s**\n", strings.Title(contentType.Label())))
		for _, eventType := range arr.SupportedEventTypes(contentType) {
			enabled := findPreference(preferences, contentType, eventType)
			builder.WriteString(fmt.Sprintf("- `%s`: %t\n", eventType, enabled))
		}
	}
	ctx.Reply(builder.String())
}

func handleSubscriptionSet(ctx *Context, repo subscriptionRepo, contentType arr.ContentType, eventType string, enabled bool) {
	var err error
	if eventType == "all" {
		err = repo.SetAll(ctx.Ctx, ctx.User.MXID, contentType, enabled)
	} else {
		err = repo.Set(ctx.Ctx, ctx.User.MXID, contentType, eventType, enabled)
	}
	if err != nil {
		ctx.Reply("Failed to update subscriptions: %v", err)
		return
	}
	if eventType == "all" {
		ctx.Reply("Set all `%s` notifications for %s to %t.", contentType.Label(), userIDString(ctx.User.MXID), enabled)
		return
	}
	ctx.Reply("Set `%s/%s` notifications to %t.", contentType.Label(), eventType, enabled)
}

type subscriptionRepo interface {
	List(ctx context.Context, userID id.UserID) ([]subscriptions.Preference, error)
	Set(ctx context.Context, userID id.UserID, contentType arr.ContentType, eventType string, enabled bool) error
	SetAll(ctx context.Context, userID id.UserID, contentType arr.ContentType, enabled bool) error
}

func findPreference(preferences []subscriptions.Preference, contentType arr.ContentType, eventType string) bool {
	for _, preference := range preferences {
		if preference.ContentType == contentType && preference.EventType == eventType {
			return preference.Enabled
		}
	}
	return true
}
