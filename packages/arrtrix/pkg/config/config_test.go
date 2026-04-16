package config

import (
	"testing"

	"maunium.net/go/mautrix/bridgev2/bridgeconfig"
)

func TestLoadDefaultsHomeserverSoftware(t *testing.T) {
	cfg, err := Load([]byte(`
bridge:
  command_prefix: "!arr"
homeserver:
  address: http://127.0.0.1:8008
  domain: test.local
appservice:
  id: arrtrix
  bot:
    username: arrtrixbot
    displayname: Arrtrix Bot
  username_template: arrtrix_{{.}}
database:
  type: sqlite3-fk-wal
  uri: file:arrtrix.db?_txlock=immediate
logging:
  min_level: info
  writers:
    - type: stdout
      format: pretty-colored
`))
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}

	if cfg.Homeserver.Software != bridgeconfig.SoftwareStandard {
		t.Fatalf("expected homeserver software default %q, got %q", bridgeconfig.SoftwareStandard, cfg.Homeserver.Software)
	}
}

func TestCompileSetsInternalDefaultsForHiddenSections(t *testing.T) {
	cfg, err := Load([]byte(`
bridge:
  command_prefix: "!arr"
  permissions:
    "*": relay
homeserver:
  address: http://127.0.0.1:8008
  domain: test.local
appservice:
  id: arrtrix
  bot:
    username: arrtrixbot
    displayname: Arrtrix Bot
  username_template: arrtrix_{{.}}
database:
  type: sqlite3-fk-wal
  uri: file:arrtrix.db?_txlock=immediate
logging:
  min_level: info
  writers:
    - type: stdout
      format: pretty-colored
`))
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}

	runtimeCfg := cfg.Compile()
	if !runtimeCfg.Matrix.MessageErrorNotices {
		t.Fatalf("expected message error notices to stay enabled")
	}
	if !runtimeCfg.Matrix.FederateRooms {
		t.Fatalf("expected federated rooms to stay enabled")
	}
	if runtimeCfg.DoublePuppet.Servers == nil || runtimeCfg.DoublePuppet.Secrets == nil {
		t.Fatalf("expected hidden double puppet maps to be initialized")
	}
}

func TestLoadIgnoresLegacyHiddenSections(t *testing.T) {
	cfg, err := Load([]byte(`
bridge:
  command_prefix: "!arr"
homeserver:
  address: http://127.0.0.1:8008
  domain: test.local
appservice:
  id: arrtrix
  bot:
    username: arrtrixbot
    displayname: Arrtrix Bot
  username_template: arrtrix_{{.}}
database:
  type: sqlite3-fk-wal
  uri: file:arrtrix.db?_txlock=immediate
logging:
  min_level: info
  writers:
    - type: stdout
      format: pretty-colored
matrix:
  federate_rooms: false
provisioning:
  shared_secret: ignored
double_puppet:
  secrets:
    test.local: secret
encryption:
  allow: true
`))
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}

	runtimeCfg := cfg.Compile()
	if !runtimeCfg.Matrix.FederateRooms {
		t.Fatalf("expected runtime defaults to win for hidden legacy sections")
	}
	if len(runtimeCfg.DoublePuppet.Secrets) != 0 {
		t.Fatalf("expected hidden double puppet secrets to stay internal-only")
	}
}
