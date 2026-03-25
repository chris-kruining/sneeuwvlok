{ pkgs, config, lib, namespace, ... }:
let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.services.observability.prometheus;
in
{
  options.sneeuwvlok.services.observability.prometheus = {
    enable = mkEnableOption "enable Prometheus";
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = 9002;

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
