package matrixcmd

import (
	"fmt"
	"strconv"
	"strings"

	"maunium.net/go/mautrix/id"

	"sneeuwvlok/packages/arrtrix/pkg/arr"
	"sneeuwvlok/packages/arrtrix/pkg/arrclient"
	"sneeuwvlok/packages/arrtrix/pkg/subscriptions"
)

type commandServiceProvider interface {
	ContentClient(arr.ContentType) (arrclient.Client, bool)
	Subscriptions() *subscriptions.Repository
}

func NewDownloadHandler() Handler {
	return NewHandler(Meta{
		Name:        "download",
		Description: "Manage monitored movies and series in Arr.",
		Usage:       "<list|search|add|monitor|remove> <movies|series> [...]",
	}, func(ctx *Context) {
		if len(ctx.Args) < 2 {
			ctx.Reply("Usage: `download <list|search|add|monitor|remove> <movies|series> [...]`")
			return
		}

		contentType, err := arr.ParseContentType(ctx.Args[1])
		if err != nil {
			ctx.Reply(err.Error())
			return
		}

		client, ok := contentClient(ctx, contentType)
		if !ok {
			ctx.Reply("No %s client is configured yet.", contentType.Label())
			return
		}

		switch strings.ToLower(ctx.Args[0]) {
		case "list":
			handleDownloadList(ctx, client, contentType)
		case "search":
			handleDownloadSearch(ctx, client, contentType)
		case "add":
			handleDownloadAdd(ctx, client, contentType)
		case "monitor":
			handleDownloadMonitor(ctx, client, contentType)
		case "remove":
			handleDownloadRemove(ctx, client, contentType)
		default:
			ctx.Reply("Unknown download subcommand `%s`.", ctx.Args[0])
		}
	})
}

func handleDownloadList(ctx *Context, client arrclient.Client, contentType arr.ContentType) {
	query := strings.TrimSpace(strings.Join(ctx.Args[2:], " "))
	items, err := client.List(ctx.Ctx, query)
	if err != nil {
		ctx.Reply("Failed to list %s: %v", contentType.Label(), err)
		return
	}
	if len(items) == 0 {
		if query == "" {
			ctx.Reply("No monitored %s are currently tracked.", contentType.Label())
		} else {
			ctx.Reply("No %s matched `%s`.", contentType.Label(), query)
		}
		return
	}

	var builder strings.Builder
	builder.WriteString(fmt.Sprintf("Tracked %s:\n", contentType.Label()))
	for i, item := range items {
		if i == 10 {
			builder.WriteString("…\n")
			break
		}
		builder.WriteString(fmt.Sprintf("- `%d` %s — monitored=%t\n", item.ID, formatManagedItem(item), item.Monitored))
	}
	ctx.Reply(builder.String())
}

func handleDownloadSearch(ctx *Context, client arrclient.Client, contentType arr.ContentType) {
	query := strings.TrimSpace(strings.Join(ctx.Args[2:], " "))
	if query == "" {
		ctx.Reply("Usage: `download search %s <query>`", contentType.Label())
		return
	}
	results, err := client.Search(ctx.Ctx, query)
	if err != nil {
		ctx.Reply("Failed to search %s: %v", contentType.Label(), err)
		return
	}
	replyWithSearchResults(ctx, contentType, query, results)
}

func handleDownloadAdd(ctx *Context, client arrclient.Client, contentType arr.ContentType) {
	query := strings.TrimSpace(strings.Join(ctx.Args[2:], " "))
	if query == "" {
		ctx.Reply("Usage: `download add %s <query>`", contentType.Label())
		return
	}
	results, err := client.Search(ctx.Ctx, query)
	if err != nil {
		ctx.Reply("Failed to search %s: %v", contentType.Label(), err)
		return
	}
	result, err := arrclient.PickSingleResult(results, query)
	if err != nil {
		replyWithSearchResults(ctx, contentType, query, results)
		return
	}
	item, err := client.Add(ctx.Ctx, result)
	if err != nil {
		ctx.Reply("Failed to add %s: %v", contentType.Label(), err)
		return
	}
	ctx.Reply("Added %s to %s with id `%d`.", formatManagedItem(*item), contentType.Label(), item.ID)
}

func handleDownloadMonitor(ctx *Context, client arrclient.Client, contentType arr.ContentType) {
	if len(ctx.Args) < 4 {
		ctx.Reply("Usage: `download monitor %s <id> <on|off>`", contentType.Label())
		return
	}
	itemID, err := strconv.ParseInt(ctx.Args[2], 10, 64)
	if err != nil {
		ctx.Reply("Invalid %s id `%s`.", contentType.Label(), ctx.Args[2])
		return
	}

	state, err := parseEnabled(ctx.Args[3])
	if err != nil {
		ctx.Reply(err.Error())
		return
	}
	item, err := client.SetMonitored(ctx.Ctx, itemID, state)
	if err != nil {
		ctx.Reply("Failed to update %s monitoring: %v", contentType.Label(), err)
		return
	}
	ctx.Reply("%s is now monitored=%t.", formatManagedItem(*item), item.Monitored)
}

func handleDownloadRemove(ctx *Context, client arrclient.Client, contentType arr.ContentType) {
	if len(ctx.Args) < 3 {
		ctx.Reply("Usage: `download remove %s <id>`", contentType.Label())
		return
	}
	itemID, err := strconv.ParseInt(ctx.Args[2], 10, 64)
	if err != nil {
		ctx.Reply("Invalid %s id `%s`.", contentType.Label(), ctx.Args[2])
		return
	}
	if err = client.Delete(ctx.Ctx, itemID); err != nil {
		ctx.Reply("Failed to remove %s: %v", contentType.Label(), err)
		return
	}
	ctx.Reply("Removed `%d` from %s.", itemID, contentType.Label())
}

func contentClient(ctx *Context, contentType arr.ContentType) (arrclient.Client, bool) {
	provider, ok := ctx.Bridge.Network.(commandServiceProvider)
	if !ok {
		return nil, false
	}
	return provider.ContentClient(contentType)
}

func contentSubscriptions(ctx *Context) *subscriptions.Repository {
	provider, ok := ctx.Bridge.Network.(commandServiceProvider)
	if !ok {
		return nil
	}
	return provider.Subscriptions()
}

func replyWithSearchResults(ctx *Context, contentType arr.ContentType, query string, results []arrclient.SearchResult) {
	if len(results) == 0 {
		ctx.Reply("No %s matched `%s`.", contentType.Label(), query)
		return
	}

	var builder strings.Builder
	builder.WriteString(fmt.Sprintf("Search results for `%s` in %s:\n", query, contentType.Label()))
	for i, result := range results {
		if i == 8 {
			builder.WriteString("…\n")
			break
		}
		builder.WriteString(fmt.Sprintf("- `%d` %s\n", result.LookupID, arrclient.FormatSearchResult(result)))
	}
	builder.WriteString(fmt.Sprintf("\nRefine the query and rerun `download add %s <query>` until only one match remains.", contentType.Label()))
	ctx.Reply(builder.String())
}

func formatManagedItem(item arrclient.ManagedItem) string {
	if item.Year != 0 {
		return fmt.Sprintf("%s (%d)", item.Title, item.Year)
	}
	return item.Title
}

func parseEnabled(value string) (bool, error) {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "on", "true", "yes", "enabled":
		return true, nil
	case "off", "false", "no", "disabled":
		return false, nil
	default:
		return false, fmt.Errorf("expected `on` or `off`, got `%s`", value)
	}
}

func userIDString(userID id.UserID) string {
	return userID.String()
}
