// Command mission-control is a bubbletea TUI "mission control" dashboard for
// the sneeuwvlok netboot installer console. It replaces the plain-text
// getty.helpLine banner with a live, auto-refreshing readiness board: a
// launch-sequence style view of boot -> network link -> address -> ssh
// reachable -> connection established, plus a telemetry panel with
// hostname, interfaces, the ssh host key fingerprint and thunderbolt
// authorization state.
//
// It is meant to be launched from the interactive login shell on the
// physical console. Quitting (q / ctrl+c / esc) simply exits the program,
// which drops back to the shell that launched it - no special exit-code
// handling needed.
package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "mission-control:", err)
		os.Exit(1)
	}
}
