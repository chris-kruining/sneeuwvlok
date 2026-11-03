package main

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
)

const minColumnsForSideBySide = 94

func (m model) View() string {
	if m.quitting {
		return ""
	}

	width := m.width
	if width <= 0 {
		width = 100
	}

	sequenceContent := m.sequenceContent()
	telemetryContent := m.telemetryContent()

	var body string
	if width >= minColumnsForSideBySide {
		// Equalize panel heights by padding the shorter one with blank
		// lines, so two side-by-side boxes of differing content don't
		// produce a ragged bottom edge. Only worth doing side by side -
		// stacked, it would just waste vertical space.
		sequenceLines := strings.Count(sequenceContent, "\n") + 1
		telemetryLines := strings.Count(telemetryContent, "\n") + 1
		if maxLines := max(sequenceLines, telemetryLines); maxLines > sequenceLines {
			sequenceContent += strings.Repeat("\n", maxLines-sequenceLines)
		} else if maxLines > telemetryLines {
			telemetryContent += strings.Repeat("\n", maxLines-telemetryLines)
		}

		sequence := panelStyle.Width(60).Render(sequenceContent)
		telemetry := panelStyle.Width(60).Render(telemetryContent)
		body = lipgloss.JoinHorizontal(lipgloss.Top, sequence, " ", telemetry)
	} else {
		sequence := panelStyle.Width(60).Render(sequenceContent)
		telemetry := panelStyle.Width(60).Render(telemetryContent)
		body = lipgloss.JoinVertical(lipgloss.Left, sequence, telemetry)
	}

	// Size the banner and footer rules to match the body that actually got
	// rendered, rather than the raw terminal width - keeps the whole thing
	// reading as one cohesive boxed dashboard instead of a full-bleed title
	// over much narrower panels.
	frameWidth := lipgloss.Width(body)

	banner := renderBanner(frameWidth)
	footer := renderFooter(frameWidth)

	return lipgloss.JoinVertical(lipgloss.Left, banner, "", body, "", footer)
}

func renderBanner(width int) string {
	title := "S N E E U W V L O K    M I S S I O N   C O N T R O L"
	sub := "NETBOOT INSTALLER -- AWAITING UPLINK"
	rule := strings.Repeat("=", clamp(width, 10, 200))

	center := func(s string) string {
		pad := (len(rule) - len(s)) / 2
		if pad < 0 {
			pad = 0
		}
		return strings.Repeat(" ", pad) + s
	}

	return lipgloss.JoinVertical(lipgloss.Left,
		dimStyle.Render(rule),
		bannerStyle.Render(center(title)),
		subBannerStyle.Render(center(sub)),
		dimStyle.Render(rule),
	)
}

func (m model) sequenceContent() string {
	var b strings.Builder

	b.WriteString(panelTitleStyle.Render("LAUNCH SEQUENCE"))
	b.WriteString("\n")
	b.WriteString(dimStyle.Render(fmt.Sprintf("MISSION ELAPSED TIME  T+%s", formatDuration(m.now.Sub(m.start)))))
	b.WriteString("\n\n")

	current := m.currentStage()

	for i, s := range m.stages {
		var track string
		switch {
		case i < current:
			track = labelStyle.Render("|")
		case i == current:
			if m.blink {
				track = okStyle.Render(">")
			} else {
				track = okStyle.Render("|")
			}
		default:
			track = pendingStyle.Render(".")
		}

		var status, ts string
		switch {
		case s.reached && i == current && i == len(m.stages)-1:
			// final stage, live connection in progress - make it loud
			if m.blink {
				status = dangerStyle.Render("[ LIVE  ]")
			} else {
				status = warnStyle.Render("[ LIVE  ]")
			}
		case s.reached:
			status = okStyle.Render("[ ONLINE]")
		default:
			status = pendingStyle.Render("[STANDBY]")
		}

		if !s.at.IsZero() {
			ts = dimStyle.Render("T+" + formatDuration(s.at.Sub(m.start)))
		} else {
			ts = pendingStyle.Render("--:--:--")
		}

		label := labelStyle.Render(fmt.Sprintf("STAGE %d  %-22s", i, s.label))
		if !s.reached {
			label = pendingStyle.Render(fmt.Sprintf("STAGE %d  %-22s", i, s.label))
		}

		fmt.Fprintf(&b, " %s  %s  %s  %s\n", track, label, status, ts)
	}

	b.WriteString("\n")
	if m.ssh.Established {
		tag := warnStyle.Render("CONNECTION FROM")
		if m.blink {
			tag = dangerStyle.Render("CONNECTION FROM")
		}
		fmt.Fprintf(&b, " %s %s\n", tag, valueStyle.Render(m.ssh.RemoteAddr))
		b.WriteString(dimStyle.Render(" nixos-anywhere (or an operator) is talking to this machine right now.\n"))
	} else if m.ssh.Listening {
		b.WriteString(okStyle.Render(" STANDING BY") + dimStyle.Render(" -- sshd is up, awaiting an incoming connection.\n"))
	} else {
		b.WriteString(pendingStyle.Render(" sshd not yet reachable.\n"))
	}

	return strings.TrimRight(b.String(), "\n")
}

func (m model) telemetryContent() string {
	var b strings.Builder

	b.WriteString(panelTitleStyle.Render("TELEMETRY"))
	b.WriteString("\n\n")

	fmt.Fprintf(&b, " %s %s\n", labelStyle.Render("HOSTNAME       "), valueStyle.Render(m.hostname+".local"))
	fmt.Fprintf(&b, " %s %s\n", labelStyle.Render("UPTIME         "), valueStyle.Render(formatDuration(m.now.Sub(m.start))))
	b.WriteString("\n")

	b.WriteString(labelStyle.Render(" HOST KEY (ed25519)") + "\n")
	if m.fpErr != nil {
		b.WriteString(pendingStyle.Render("   not available yet\n"))
	} else {
		fmt.Fprintf(&b, "   %s\n", valueStyle.Render(m.fp))
	}
	b.WriteString("\n")

	b.WriteString(labelStyle.Render(" NETWORK INTERFACES") + "\n")
	if len(m.ifaces) == 0 {
		b.WriteString(pendingStyle.Render("   none detected\n"))
	}
	for _, ifc := range m.ifaces {
		state := pendingStyle.Render("DOWN")
		if ifc.Up {
			state = okStyle.Render("UP  ")
		}
		addr := pendingStyle.Render("--")
		if len(ifc.Addrs) > 0 {
			addr = valueStyle.Render(summarizeAddrs(ifc.Addrs))
		}
		fmt.Fprintf(&b, "   %-10s %s  %s\n", ifc.Name, state, addr)
	}
	b.WriteString("\n")

	b.WriteString(labelStyle.Render(" THUNDERBOLT") + "\n")
	if len(m.tb) == 0 {
		b.WriteString(pendingStyle.Render("   no devices present\n"))
	}
	for _, d := range m.tb {
		state := warnStyle.Render("UNAUTHORIZED")
		if d.Authorized {
			state = okStyle.Render("AUTHORIZED ")
		}
		fmt.Fprintf(&b, "   %-6s %-20s %s\n", d.ID, truncate(d.Name, 20), state)
	}

	return strings.TrimRight(b.String(), "\n")
}

func renderFooter(width int) string {
	rule := strings.Repeat("-", clamp(width, 10, 200))
	hint := "q / ctrl+c : drop to shell    refresh: 0.5s    sneeuwvlok installer"
	return lipgloss.JoinVertical(lipgloss.Left, dimStyle.Render(rule), footerStyle.Render(" "+hint))
}

// summarizeAddrs keeps interface rows from blowing past panel width when a
// machine has both an IPv4 lease and several IPv6 addresses (common with
// SLAAC privacy extensions): show one representative address, preferring
// IPv4 as the one most relevant to "reachable from the LAN", and fold the
// rest into a count.
func summarizeAddrs(addrs []string) string {
	primary := addrs[0]
	for _, a := range addrs {
		if strings.Contains(a, ".") {
			primary = a
			break
		}
	}
	if len(addrs) > 1 {
		return fmt.Sprintf("%s (+%d more)", primary, len(addrs)-1)
	}
	return primary
}

func formatDuration(d time.Duration) string {
	if d < 0 {
		d = 0
	}
	d = d.Round(time.Second)
	h := d / time.Hour
	d -= h * time.Hour
	mn := d / time.Minute
	d -= mn * time.Minute
	s := d / time.Second
	return fmt.Sprintf("%02d:%02d:%02d", h, mn, s)
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	if n <= 1 {
		return s[:n]
	}
	return s[:n-1] + "~"
}
