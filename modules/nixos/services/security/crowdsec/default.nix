{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption optionals types;

  cfg = config.${namespace}.services.security.crowdsec;
in {
  options.${namespace}.services.security.crowdsec = {
    enable = mkEnableOption ''
      CrowdSec, which looks for attacks in the logs of ssh and caddy. It runs in simulation mode, it only reports
      what it would ban, until a bouncer is added
    '';

    trustedNetworks = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["2001:db8::/48"];
      description = ''
        Networks of your own that are never regarded as an attacker. The private ranges already are.
      '';
    };

    lapiPort = mkOption {
      type = types.port;
      default = 9050;
    };

    metricsPort = mkOption {
      type = types.port;
      default = 9051;
    };
  };

  config = mkIf cfg.enable {
    services.crowdsec = {
      enable = true;

      hub.collections = [
        # Syslog, ssh and the whitelist of the private ranges
        "crowdsecurity/linux"
        # Caddy's access logs, with the http scenarios
        "crowdsecurity/caddy"
      ];

      localConfig = {
        acquisitions =
          [
            {
              source = "journalctl";
              journalctl_filter = ["_SYSTEMD_UNIT=sshd.service"];
              labels.type = "syslog";
            }
          ]
          ++ optionals config.services.caddy.enable [
            {
              filenames = ["${config.services.caddy.logDir}/access-*.log"];
              labels.type = "caddy";
            }
          ];

        parsers.s02Enrich = optionals (cfg.trustedNetworks != []) [
          {
            name = "${namespace}/trusted-networks";
            description = "Never regard the own networks as an attacker";
            whitelist = {
              reason = "own network";
              cidr = cfg.trustedNetworks;
            };
          }
        ];
      };

      settings = {
        # Decisions are made, but marked as simulated, nothing gets banned
        simulation.simulation = true;

        # The local api keeps the alerts and decisions, for cscli and later a bouncer
        lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";

        general = {
          api.server = {
            enable = true;
            listen_uri = "127.0.0.1:${toString cfg.lapiPort}";
            # Nothing is shared with, or pulled from, crowdsec's central api
            online_client = lib.mkForce null;
          };

          prometheus = {
            listen_addr = "127.0.0.1";
            listen_port = cfg.metricsPort;
          };
        };
      };
    };

    # The module empties the path, but the journal is read with journalctl
    systemd.services.crowdsec.path = lib.mkForce [config.systemd.package];

    # Caddy's access logs are only readable by its group
    users.users.crowdsec.extraGroups = optionals config.services.caddy.enable ["caddy"];
  };
}
