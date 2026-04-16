package onboarding

import (
	"context"
	"fmt"
	"strings"

	"github.com/rs/zerolog"

	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/bridgev2/bridgeconfig"
	"maunium.net/go/mautrix/event"
	"maunium.net/go/mautrix/format"
	"maunium.net/go/mautrix/id"
)

const handledInviteEventType = "com.arrtrix.handled_invite"

func HandleBotInvite(ctx context.Context, bridge *bridgev2.Bridge, texts bridgeconfig.ManagementRoomTexts, evt *event.Event) {
	if evt.Type != event.StateMember ||
		evt.GetStateKey() != bridge.Bot.GetMXID().String() ||
		evt.Content.AsMember().Membership != event.MembershipInvite {
		return
	}

	log := zerolog.Ctx(ctx)
	sender, err := bridge.GetUserByMXID(ctx, evt.Sender)
	if err != nil {
		log.Err(err).Msg("Failed to load sender for bot invite")
		return
	}
	if !sender.Permissions.Commands {
		return
	}

	if err = bridge.Bot.EnsureJoined(ctx, evt.RoomID); err != nil {
		log.Err(err).Msg("Failed to accept invite to room")
		return
	}

	members, err := bridge.Matrix.GetMembers(ctx, evt.RoomID)
	if err != nil {
		log.Err(err).Msg("Failed to get members of room after accepting invite")
		return
	}
	if len(members) != 2 {
		return
	}

	assignedManagementRoom := sender.ManagementRoom == ""
	if assignedManagementRoom {
		sender.ManagementRoom = evt.RoomID
		if err = sender.Save(ctx); err != nil {
			log.Err(err).Msg("Failed to update user's management room in database")
			return
		}
	}

	message := buildWelcomeMessage(bridge, texts, sender, assignedManagementRoom)
	content := format.RenderMarkdown(message, true, false)
	if _, err = bridge.Bot.SendMessage(ctx, evt.RoomID, event.EventMessage, &event.Content{Parsed: &content}, nil); err != nil {
		log.Err(err).Msg("Failed to send welcome message to room")
		return
	}

	evt.Type = event.Type{Type: handledInviteEventType}
}

func buildWelcomeMessage(bridge *bridgev2.Bridge, texts bridgeconfig.ManagementRoomTexts, sender *bridgev2.User, assignedManagementRoom bool) string {
	return composeWelcomeMessage(
		bridge.Network.GetName().DisplayName,
		bridge.Config.CommandPrefix,
		bridge.Bot.GetMXID(),
		texts,
		sender.GetDefaultLogin() != nil,
		assignedManagementRoom,
	)
}

func composeWelcomeMessage(
	bridgeName string,
	commandPrefix string,
	botMXID id.UserID,
	texts bridgeconfig.ManagementRoomTexts,
	connected bool,
	assignedManagementRoom bool,
) string {
	replacer := strings.NewReplacer(
		"$cmdprefix", commandPrefix,
		"$bridge", bridgeName,
		"$bot", string(botMXID),
	)

	var parts []string

	base := strings.TrimSpace(texts.Welcome)
	if base == "" {
		base = fmt.Sprintf("Hello, I'm the %s bot.", bridgeName)
	}
	parts = append(parts, replacer.Replace(base))

	if assignedManagementRoom {
		parts = append(parts, "This room has been marked as your management room.")
	} else {
		parts = append(parts, fmt.Sprintf("Use `%s help` to see available commands in this room.", commandPrefix))
	}

	if connected {
		connected := strings.TrimSpace(texts.WelcomeConnected)
		if connected == "" {
			connected = "You're connected. Use `help` to see the commands available right now."
		}
		parts = append(parts, replacer.Replace(connected))
	} else {
		unconnected := strings.TrimSpace(texts.WelcomeUnconnected)
		if unconnected == "" {
			unconnected = "Use `help` to see the commands available right now."
		}
		parts = append(parts, replacer.Replace(unconnected))
	}

	if extra := strings.TrimSpace(texts.AdditionalHelp); extra != "" {
		parts = append(parts, replacer.Replace(extra))
	}

	return strings.Join(parts, "\n\n")
}

func IsHandledInviteEvent(evt *event.Event) bool {
	return evt.Type.Type == handledInviteEventType
}

func IsBotInviteFor(roomBot id.UserID, evt *event.Event) bool {
	return evt.Type == event.StateMember &&
		evt.GetStateKey() == roomBot.String() &&
		evt.Content.AsMember().Membership == event.MembershipInvite
}
