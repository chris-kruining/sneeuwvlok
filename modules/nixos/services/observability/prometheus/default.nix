{ pkgs, config, lib, namespace, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

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

      globalConfig.scrape_interval = "15s";

      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [
            { targets = [ "localhost:9002" ]; }
          ];
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [ 9002 ];
  };
}
