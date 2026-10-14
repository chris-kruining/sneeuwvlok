{ pkgs, config, lib, namespace, ... }:
let
  inherit (builtins) toString;
  inherit (lib) mkEnableOption mkIf optionals;

  cfg = config.${namespace}.services.observability.prometheus;
in
{
  options.${namespace}.services.observability.prometheus = {
    enable = mkEnableOption "enable Prometheus";
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      # Grafana is the frontend, nothing else needs to reach Prometheus
      listenAddress = "[::1]";
      port = 9020;
      retentionTime = "90d";
      extraFlags = optionals config.${namespace}.services.observability.alloy.enable [
        "--web.enable-remote-write-receiver"
      ];

      globalConfig.scrape_interval = "15s";

      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [
            { targets = [ "[::1]:9020" ]; }
          ];
        }

        {
          job_name = "node";
          static_configs = [
            { targets = [ "[::1]:${toString config.services.prometheus.exporters.node.port}" ]; }
          ];
        }
      ]
      ++ optionals config.${namespace}.services.observability.alloy.enable [
        {
          job_name = "alloy";
          static_configs = [
            { targets = [ "[::1]:9070" ]; }
          ];
        }
      ]
      ++ optionals config.${namespace}.services.observability.tempo.enable [
        {
          job_name = "tempo";
          static_configs = [
            { targets = [ "[::1]:9060" ]; }
          ];
        }
      ];

      exporters = {
        node = {
          enable = true;
          listenAddress = "[::1]";
          port = 9021;
          enabledCollectors = [ "systemd" ];
        };
      };
    };
  };
}
