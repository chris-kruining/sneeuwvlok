package main

import (
	"os"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

const tickInterval = 500 * time.Millisecond

const sshKeyPath = "/etc/ssh/ssh_host_ed25519_key.pub"

// stage is one step of the launch sequence.
type stage struct {
	label   string
	reached bool
	at      time.Time // zero until reached
}

type tickMsg time.Time

// model is the whole TUI state. It is re-derived from the live system every
// tick rather than incrementally patched, since all the underlying reads
// (/proc, /sys, net.Interfaces) are cheap and this keeps the logic simple
// and always-correct instead of stateful and potentially stale.
type model struct {
	start time.Time
	now   time.Time
	blink bool

	width  int
	height int

	hostname string
	fp       string
	fpErr    error

	ifaces []Iface
	ssh    SSHStatus
	tb     []TBDevice

	stages [5]stage

	quitting bool
}

func initialModel() model {
	hostname, _ := os.Hostname()
	fp, fpErr := hostKeyFingerprint(sshKeyPath)

	m := model{
		start:    time.Now(),
		now:      time.Now(),
		hostname: hostname,
		fp:       fp,
		fpErr:    fpErr,
	}
	m.stages[0] = stage{label: "BOOT"}
	m.stages[1] = stage{label: "NETWORK LINK"}
	m.stages[2] = stage{label: "ADDRESS ACQUIRED"}
	m.stages[3] = stage{label: "SSH REACHABLE"}
	m.stages[4] = stage{label: "CONNECTION / INSTALL"}
	return m
}

func (m model) Init() tea.Cmd {
	return tea.Batch(tick(), tea.EnterAltScreen)
}

func tick() tea.Cmd {
	return tea.Tick(tickInterval, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			m.quitting = true
			return m, tea.Quit
		}
		return m, nil

	case tickMsg:
		m.refresh(time.Time(msg))
		return m, tick()
	}

	return m, nil
}

// refresh re-samples the live system and advances the launch sequence.
func (m *model) refresh(now time.Time) {
	m.now = now
	m.blink = now.UnixMilli()/int64(tickInterval/time.Millisecond)%2 == 0

	m.ifaces = collectInterfaces()
	m.ssh = sshStatus()
	m.tb = thunderboltDevices()

	live := [5]bool{
		true,
		hasCarrier(m.ifaces),
		hasAddress(m.ifaces),
		m.ssh.Listening,
		m.ssh.Established,
	}

	// Each stage's "reached" flag tracks the live state directly, so a
	// dropped link or a closed ssh session visibly un-lights - this is a
	// status board, not a one-way checklist. The "at" timestamp is sticky
	// though: it records when the stage was *first* reached, for the T+
	// readout, and isn't reset by later flapping.
	for i, l := range live {
		if l && m.stages[i].at.IsZero() {
			m.stages[i].at = now
		}
		m.stages[i].reached = l
	}
}

// currentStage is the index of the furthest stage reached - the one that
// should pulse as "active".
func (m model) currentStage() int {
	idx := 0
	for i, s := range m.stages {
		if s.reached {
			idx = i
		}
	}
	return idx
}
