package main

import (
	"bufio"
	"encoding/hex"
	"net"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"golang.org/x/crypto/ssh"
)

// Iface is a snapshot of one non-loopback network interface.
type Iface struct {
	Name  string
	Up    bool
	Addrs []string
}

func collectInterfaces() []Iface {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil
	}

	out := make([]Iface, 0, len(ifaces))
	for _, ifc := range ifaces {
		if ifc.Flags&net.FlagLoopback != 0 {
			continue
		}

		it := Iface{Name: ifc.Name, Up: ifc.Flags&net.FlagUp != 0}

		addrs, _ := ifc.Addrs()
		for _, a := range addrs {
			ipnet, ok := a.(*net.IPNet)
			if !ok {
				continue
			}
			if ipnet.IP.IsLinkLocalUnicast() || ipnet.IP.IsLinkLocalMulticast() {
				continue
			}
			it.Addrs = append(it.Addrs, a.String())
		}

		out = append(out, it)
	}

	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}

func hasCarrier(ifaces []Iface) bool {
	for _, i := range ifaces {
		if i.Up {
			return true
		}
	}
	return false
}

func hasAddress(ifaces []Iface) bool {
	for _, i := range ifaces {
		if i.Up && len(i.Addrs) > 0 {
			return true
		}
	}
	return false
}

// TCPConn is one row parsed out of /proc/net/tcp{,6}.
type TCPConn struct {
	LocalPort  uint16
	RemoteIP   net.IP
	RemotePort uint16
	State      string
}

const (
	tcpStateEstablished = "01"
	tcpStateListen      = "0A"
)

func parseProcNetTCP(path string, v6 bool) []TCPConn {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	var conns []TCPConn
	sc := bufio.NewScanner(f)
	sc.Scan() // header line
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) < 4 {
			continue
		}

		local := strings.Split(fields[1], ":")
		remote := strings.Split(fields[2], ":")
		if len(local) != 2 || len(remote) != 2 {
			continue
		}

		lp, err := strconv.ParseUint(local[1], 16, 16)
		if err != nil {
			continue
		}
		rp, _ := strconv.ParseUint(remote[1], 16, 16)

		conns = append(conns, TCPConn{
			LocalPort:  uint16(lp),
			RemoteIP:   parseHexIP(remote[0], v6),
			RemotePort: uint16(rp),
			State:      fields[3],
		})
	}
	return conns
}

// parseHexIP decodes the little-endian-per-word hex IP encoding used by
// /proc/net/tcp (IPv4) and /proc/net/tcp6 (IPv6).
func parseHexIP(s string, v6 bool) net.IP {
	b, err := hex.DecodeString(s)
	if err != nil {
		return nil
	}

	if !v6 {
		if len(b) != 4 {
			return nil
		}
		return net.IPv4(b[3], b[2], b[1], b[0])
	}

	if len(b) != 16 {
		return nil
	}
	ip := make(net.IP, 16)
	for i := 0; i < 16; i += 4 {
		ip[i], ip[i+1], ip[i+2], ip[i+3] = b[i+3], b[i+2], b[i+1], b[i]
	}
	return ip
}

// SSHStatus reflects whether sshd is listening on :22 and whether some peer
// currently has an established connection to it - the real "someone is
// installing me right now" signal.
type SSHStatus struct {
	Listening   bool
	Established bool
	RemoteAddr  string
}

func sshStatus() SSHStatus {
	var conns []TCPConn
	conns = append(conns, parseProcNetTCP("/proc/net/tcp", false)...)
	conns = append(conns, parseProcNetTCP("/proc/net/tcp6", true)...)

	var s SSHStatus
	for _, c := range conns {
		if c.LocalPort != 22 {
			continue
		}
		switch c.State {
		case tcpStateListen:
			s.Listening = true
		case tcpStateEstablished:
			s.Established = true
			if c.RemoteIP != nil {
				s.RemoteAddr = c.RemoteIP.String()
			}
		}
	}
	return s
}

// TBDevice is one thunderbolt device and its authorization state.
type TBDevice struct {
	ID         string
	Name       string
	Authorized bool
}

const thunderboltSysfs = "/sys/bus/thunderbolt/devices"

func thunderboltDevices() []TBDevice {
	entries, err := os.ReadDir(thunderboltSysfs)
	if err != nil {
		return nil
	}

	var devs []TBDevice
	for _, e := range entries {
		id := e.Name()

		// Domain controllers (e.g. "0-0") and similar bus-level entries
		// don't carry an "authorized" attribute - only actual devices do.
		authData, err := os.ReadFile(filepath.Join(thunderboltSysfs, id, "authorized"))
		if err != nil {
			continue
		}

		name := id
		if nb, err := os.ReadFile(filepath.Join(thunderboltSysfs, id, "device_name")); err == nil {
			if n := strings.TrimSpace(string(nb)); n != "" {
				name = n
			}
		}

		devs = append(devs, TBDevice{
			ID:         id,
			Name:       name,
			Authorized: strings.TrimSpace(string(authData)) == "1",
		})
	}

	sort.Slice(devs, func(i, j int) bool { return devs[i].ID < devs[j].ID })
	return devs
}

// hostKeyFingerprint computes the SHA256 fingerprint of the host's ed25519
// ssh key, the same format `ssh-keygen -lf` prints, straight from Go instead
// of shelling out.
func hostKeyFingerprint(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}

	pub, _, _, _, err := ssh.ParseAuthorizedKey(data)
	if err != nil {
		return "", err
	}

	return ssh.FingerprintSHA256(pub), nil
}

func readUptimeSeconds() float64 {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return 0
	}
	fields := strings.Fields(string(data))
	if len(fields) == 0 {
		return 0
	}
	v, _ := strconv.ParseFloat(fields[0], 64)
	return v
}
