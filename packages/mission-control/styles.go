package main

import "github.com/charmbracelet/lipgloss"

// Palette: classic phosphor-terminal green/amber on black. Deliberately
// restricted to the basic 16-color ANSI palette (not 256-color / true
// color) because this renders on the raw Linux virtual console, which only
// reliably supports the standard set.
var (
	colGreen       = lipgloss.Color("2")
	colBrightGreen = lipgloss.Color("10")
	colAmber       = lipgloss.Color("3")
	colBrightAmber = lipgloss.Color("11")
	colRed         = lipgloss.Color("1")
	colBrightRed   = lipgloss.Color("9")
	colGray        = lipgloss.Color("8")
	colWhite       = lipgloss.Color("15")
)

// asciiBorder is a plain-ASCII box border. The Linux console's default font
// usually has box-drawing glyphs too, but this is cheap insurance against a
// font that doesn't, and it fits the "ancient mission control CRT" vibe
// better than crisp unicode lines anyway.
var asciiBorder = lipgloss.Border{
	Top:         "-",
	Bottom:      "-",
	Left:        "|",
	Right:       "|",
	TopLeft:     "+",
	TopRight:    "+",
	BottomLeft:  "+",
	BottomRight: "+",
}

var (
	bannerStyle = lipgloss.NewStyle().
			Foreground(colBrightGreen).
			Bold(true)

	subBannerStyle = lipgloss.NewStyle().
			Foreground(colAmber)

	panelStyle = lipgloss.NewStyle().
			Border(asciiBorder).
			BorderForeground(colGreen).
			Foreground(colGreen).
			Padding(0, 1)

	panelTitleStyle = lipgloss.NewStyle().
			Foreground(colBrightAmber).
			Bold(true)

	okStyle = lipgloss.NewStyle().
		Foreground(colBrightGreen).
		Bold(true)

	warnStyle = lipgloss.NewStyle().
			Foreground(colBrightAmber).
			Bold(true)

	pendingStyle = lipgloss.NewStyle().
			Foreground(colGray)

	dangerStyle = lipgloss.NewStyle().
			Foreground(colBrightRed).
			Bold(true)

	dimStyle = lipgloss.NewStyle().
			Foreground(colGray)

	labelStyle = lipgloss.NewStyle().
			Foreground(colGreen)

	valueStyle = lipgloss.NewStyle().
			Foreground(colWhite)

	footerStyle = lipgloss.NewStyle().
			Foreground(colGray)
)
