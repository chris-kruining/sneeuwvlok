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

          links = [];

          services = [
            {
              name = "Services";
              items = [
                {
                  name = "Zitadel";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/zitadel.svg";
                  tag = "app";
                  url = "https://auth.kruining.eu";
                  target = "_blank";
                }

                {
                  name = "Forgejo";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/forgejo.svg";
                  tag = "app";
                  type = "Gitea";
                  url = "https://git.amarth.cloud";
                  target = "_blank";
                }

                {
                  name = "Vaultwarden";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/vaultwarden.svg";
                  type = "Vaultwarden";
                  tag = "app";
                  url = "https://vault.kruining.eu";
                  target = "_blank";
                }
              ];
            }

            {
              name = "Observability";
              items = [
                {
                  name = "Grafana";
                  type = "Grafana";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/grafana.svg";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.grafana.settings.server.http_port}";
                  target = "_blank";
                }

                {
                  name = "Prometheus";
                  type = "Prometheus";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/prometheus.svg";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.prometheus.port}";
                  target = "_blank";
                }
              ];
            }

            {
              name = "Media";
              items = [
                {
                  name = "Jellyfin (Movies)";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/jellyfin.svg";
                  tag = "app";
                  type = "Emby";
                  url = "http://${config.networking.hostName}:8096";
                  apikey = "e3ceed943eeb409ba8342738db7cc1f5";
                  libraryType = "movies";
                  target = "_blank";
                }

                {
                  name = "Radarr";
                  type = "Radarr";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/radarr.svg";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.radarr.settings.server.port}";
                  target = "_blank";
                }

                {
                  name = "Sonarr";
                  type = "Sonarr";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/sonarr.svg";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.sonarr.settings.server.port}";
                  target = "_blank";
                }

                {
                  name = "Lidarr";
                  type = "Lidarr";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/lidarr.svg";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.lidarr.settings.server.port}";
                  target = "_blank";
                }

                {
                  name = "Prowlarr";
                  type = "Prowlarr";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/prowlarr.svg";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.prowlarr.settings.server.port}";
                  target = "_blank";
                }

                {
                  name = "qBittorrent";
                  type = "qBittorrent";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/qbittorrent.svg";
                  tag = "app";
                  url = "http://${config.networking.hostName}:${builtins.toString config.services.qbittorrent.webuiPort}";
                  target = "_blank";
                }

                {
                  name = "SABnzbd";
                  type = "SABnzbd";
                  logo = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/sabnzdb-light.svg";
                  tag = "app";
                  url = "http://${config.networking.hostName}:8080";
                  target = "_blank";
                }
              ];
            }
          ];
        };
      };
    };
  };
}
