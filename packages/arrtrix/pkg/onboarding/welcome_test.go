package onboarding

import (
	"strings"
	"testing"

	"maunium.net/go/mautrix/bridgev2/bridgeconfig"
	"maunium.net/go/mautrix/id"
)

func TestComposeWelcomeMessageDefaults(t *testing.T) {
	out := composeWelcomeMessage(
		"Arrtrix",
		"!arr",
		id.UserID("@arrtrixbot:test"),
		bridgeconfig.ManagementRoomTexts{},
		false,
		true,
	)

	for _, fragment := range []string{
		"Hello, I'm the Arrtrix bot.",
		"This room has been marked as your management room.",
		"Use `help` to see the commands available right now.",
	} {
		if !strings.Contains(out, fragment) {
			t.Fatalf("expected welcome output to contain %q, got:\n%s", fragment, out)
		}
	}
}

func TestComposeWelcomeMessageTemplateValues(t *testing.T) {
	out := composeWelcomeMessage(
		"Arrtrix",
		"!arr",
		id.UserID("@arrtrixbot:test"),
		bridgeconfig.ManagementRoomTexts{
			Welcome:          "Welcome to $bridge.",
			WelcomeConnected: "Talk to $bot with $cmdprefix help.",
			AdditionalHelp:   "Custom footer for $bridge.",
		},
		true,
		false,
	)

	for _, fragment := range []string{
		"Welcome to Arrtrix.",
		"Use `!arr help` to see available commands in this room.",
		"Talk to @arrtrixbot:test with !arr help.",
		"Custom footer for Arrtrix.",
	} {
		if !strings.Contains(out, fragment) {
			t.Fatalf("expected templated welcome output to contain %q, got:\n%s", fragment, out)
		}
	}
}
