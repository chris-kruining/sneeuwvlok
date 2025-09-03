{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.media.homer;
in
{
  options.${namespace}.services.media.homer = {
    enable = mkEnableOption "Enable homer";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 2000 ];

    services = {
      homer = {
        enable = true;

        virtualHost = {
          caddy.enable = true;
          domain = "http://:2000";
        };

        settings = {
          title = "Ulmo dashboard";

          columns = 4;
          connectivityCheck = true;

          links = [
            {
              name = "Git";
              icon = "fab fa-forgejo";
              url = "https://git.amarth.cloud";

            }
          ];

          services = [
            {
              name = "Services";
              items = [
                {
                  name = "Zitadel";
                  tag = "app";
                  url = "https://auth.amarth.cloud";
                }

                {
                  name = "Forgejo";
                  tag = "app";
                  url = "https://git.amarth.cloud";
                }

                {
                  name = "Vaultwarden";
                  tag = "app";
                  url = "https://vault.kruining.eu";
                }
              ];
            }

            {
              name = "Observability";
              items = [
                {
                  name = "Grafana";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.grafana.settings.server.http_port}";
                }
              ];
            }

            {
              name = "Media";
              items = [
                {
                  name = "Jellyfin";
                  tag = "app";
                  url = "http://${config.networking.hostName}:8096";
                }

                {
                  name = "Radarr";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.radarr.settings.server.port}";
                }

                {
                  name = "Sonarr";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.sonarr.settings.server.port}";
                }

                {
                  name = "Lidarr";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.lidarr.settings.server.port}";
                }

                {
                  name = "qBitTorrent";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.qbittorrent.webuiPort}";
                }

                {
                  name = "SabNZB";
                  tag = "app";
                  url = "http://${config.networking.hostName}:8080";
                }

              ];
            }
          ];
        };
      };
    };
  };
}
