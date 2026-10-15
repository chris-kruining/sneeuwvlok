{
  config,
  pkgs,
  lib,
  namespace,
  ...
}: let
  inherit (builtins) length;
  inherit (lib) mkIf mkEnableOption mkOption types attrNames mapAttrs replaceStrings;

  cfg = config.${namespace}.services.networking.caddy;
  hasHosts = (cfg.hosts |> attrNames |> length) > 0;
in {
  options.${namespace}.services.networking.caddy = {
    enable = mkEnableOption "enable caddy" // {default = true;};

    hosts = mkOption {
      type = types.attrsOf types.str;
    };

    extraConfig = mkOption {
      type = types.str;
    };
  };

  config = mkIf hasHosts {
    networking.firewall.allowedTCPPorts = [80 443];

    services.caddy = {
      enable = cfg.enable;

      package = pkgs.caddy.withPlugins {
        plugins = ["github.com/corazawaf/coraza-caddy/v2@v2.1.0"];
        hash = "sha256-LhCmRyJtJw5GFXtMajZI8+Q0V4nbzvUEuARSdnpoax4=";
      };

      # Request metrics per host, scraped by prometheus on the admin endpoint
      globalConfig = ''
        metrics {
          per_host
        }
      '';

      virtualHosts =
        cfg.hosts
        |> mapAttrs (host: extraConfig: {
          inherit extraConfig;

          # Same as the default, but readable by the caddy group so alloy can ship them to loki
          logFormat = ''
            output file ${config.services.caddy.logDir}/access-${replaceStrings ["/" " "] ["_" "_"] host}.log {
              mode 0640
            }
          '';
        });
    };

    # Caddy keeps the mode of log files that already exist
    systemd.tmpfiles.rules = ["z ${config.services.caddy.logDir}/access-*.log 0640 caddy caddy -"];
  };
}
