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
      port = 9002;
      extraFlags = optionals config.${namespace}.services.observability.alloy.enable [
        "--web.enable-remote-write-receiver"
      ];

      globalConfig.scrape_interval = "15s";

      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [
            { targets = [ "localhost:9002" ]; }
          ];
        }

        {
          job_name = "node";
          static_configs = [
            { targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]; }
          ];
        }
      ]
      ++ optionals config.${namespace}.services.observability.alloy.enable [
        {
          job_name = "alloy";
          static_configs = [
            { targets = [ "localhost:9007" ]; }
          ];
        }
      ]
      ++ optionals config.${namespace}.services.observability.tempo.enable [
        {
          job_name = "tempo";
          static_configs = [
            { targets = [ "localhost:9006" ]; }
          ];
        }
      ];

      exporters = {
        node = {
          enable = true;
          port = 9005;
          enabledCollectors = [ "systemd" ];
          openFirewall = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 9002 ];
  };
}
