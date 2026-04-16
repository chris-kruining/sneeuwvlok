package config

import (
	"go.mau.fi/util/dbutil"
	"go.mau.fi/zeroconfig"
	"gopkg.in/yaml.v3"

	"maunium.net/go/mautrix/bridgev2/bridgeconfig"

	"sneeuwvlok/packages/arrtrix/pkg/observability"
)

type Config struct {
	Network yaml.Node `yaml:"network"`

	Bridge     bridgeconfig.BridgeConfig     `yaml:"bridge"`
	Database   dbutil.Config                 `yaml:"database"`
	Homeserver bridgeconfig.HomeserverConfig `yaml:"homeserver"`
	AppService bridgeconfig.AppserviceConfig `yaml:"appservice"`
	Logging    zeroconfig.Config             `yaml:"logging"`

	Observability   observability.Config             `yaml:"observability"`
	EnvConfigPrefix string                           `yaml:"env_config_prefix"`
	ManagementTexts bridgeconfig.ManagementRoomTexts `yaml:"management_room_texts"`
}

func Load(data []byte) (*Config, error) {
	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	cfg.applyDefaults()
	return &cfg, nil
}

func (c *Config) applyDefaults() {
	if c.Homeserver.Software == "" {
		c.Homeserver.Software = bridgeconfig.SoftwareStandard
	}
	c.Observability.ApplyDefaults()
}

func (c *Config) Compile() bridgeconfig.Config {
	return bridgeconfig.Config{
		Network:             c.Network,
		Bridge:              c.Bridge,
		Database:            c.Database,
		Homeserver:          c.Homeserver,
		AppService:          c.AppService,
		Logging:             c.Logging,
		EnvConfigPrefix:     c.EnvConfigPrefix,
		ManagementRoomTexts: c.ManagementTexts,
		Matrix: bridgeconfig.MatrixConfig{
			MessageStatusEvents: false,
			DeliveryReceipts:    false,
			MessageErrorNotices: true,
			SyncDirectChatList:  false,
			FederateRooms:       true,
		},
		DoublePuppet: bridgeconfig.DoublePuppetConfig{
			Servers: map[string]string{},
			Secrets: map[string]string{},
		},
	}
}
