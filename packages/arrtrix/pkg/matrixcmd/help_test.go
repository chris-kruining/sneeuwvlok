package matrixcmd

import (
	"strings"
	"testing"

	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/bridgev2/bridgeconfig"
	"maunium.net/go/mautrix/bridgev2/database"
	"maunium.net/go/mautrix/id"
)

func TestFormatHelpManagementRoom(t *testing.T) {
	roomID := id.RoomID("!arrtrix:test")
	proc := &Processor{
		texts:   bridgeconfig.ManagementRoomTexts{AdditionalHelp: "Extra help text."},
		command: make(map[string]Handler),
		alias:   make(map[string]string),
	}
	proc.Add(NewHelpHandler(proc))

	out := formatHelp(proc, &Context{
		Bridge: &bridgev2.Bridge{
			Config: &bridgeconfig.BridgeConfig{
				CommandPrefix: "!arr",
			},
		},
		RoomID:    roomID,
		User:      &bridgev2.User{User: &database.User{ManagementRoom: roomID}},
		Processor: proc,
	})

	for _, fragment := range []string{
		"prefixing commands with `!arr` is not required",
		"**help** - Show this help message.",
		"Extra help text.",
	} {
		if !strings.Contains(out, fragment) {
			t.Fatalf("expected help output to contain %q, got:\n%s", fragment, out)
		}
	}
}
