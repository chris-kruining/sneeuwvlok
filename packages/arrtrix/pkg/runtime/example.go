package runtime

import (
	"fmt"
	"strings"

	"maunium.net/go/mautrix/bridgev2"
)

func makeExampleConfig(networkName bridgev2.BridgeName, networkExample string) string {
	var builder strings.Builder

	builder.WriteString("# Network-specific config options\n")
	builder.WriteString("network:\n")
	for _, line := range strings.Split(strings.TrimRight(networkExample, "\n"), "\n") {
		if line == "" {
			builder.WriteString("  \n")
			continue
		}
		builder.WriteString("  ")
		builder.WriteString(line)
		builder.WriteByte('\n')
	}
	builder.WriteByte('\n')

	builder.WriteString(fmt.Sprintf(`bridge:
  command_prefix: "%s"
  permissions:
    "*": relay
    "@admin:example.com": admin

database:
  type: sqlite3-fk-wal
  uri: file:arrtrix.db?_txlock=immediate

homeserver:
  address: http://example.localhost:8008
  domain: example.com
  software: standard

appservice:
  address: http://localhost:%d
  hostname: 127.0.0.1
  port: %d
  id: %s
  bot:
    username: %s
    displayname: %s
  as_token: This value is generated when generating the registration
  hs_token: This value is generated when generating the registration
  username_template: %s_{{.}}

logging:
  min_level: info
  writers:
    - type: stdout
      format: pretty-colored

observability:
  # OTLP/gRPC endpoint for logs, traces, and metrics.
  # Set to e.g. http://127.0.0.1:4317 to enable export.
  otlp_grpc_endpoint: ""
  service_name: arrtrix
  resource_attributes: {}

management_room_texts:
  welcome: ""
  welcome_connected: ""
  welcome_unconnected: ""
  additional_help: ""

env_config_prefix: ""
`, networkName.DefaultCommandPrefix, networkName.DefaultPort, networkName.DefaultPort, networkName.NetworkID, "arrtrixbot", "Arrtrix Bot", networkName.NetworkID))

	return builder.String()
}
