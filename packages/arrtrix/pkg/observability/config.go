package observability

import "strings"

type Config struct {
	OTLPGRPCEndpoint   string            `yaml:"otlp_grpc_endpoint"`
	ServiceName        string            `yaml:"service_name"`
	ResourceAttributes map[string]string `yaml:"resource_attributes"`
}

func (c *Config) ApplyDefaults() {
	if c.ServiceName == "" {
		c.ServiceName = "arrtrix"
	}
	if c.ResourceAttributes == nil {
		c.ResourceAttributes = map[string]string{}
	}
}

func (c Config) Enabled() bool {
	return strings.TrimSpace(c.OTLPGRPCEndpoint) != ""
}
