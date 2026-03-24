{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.media.glance;
in {
  options.${namespace}.services.media.glance = {
    enable = mkEnableOption "Enable Glance";
  };

  config = mkIf cfg.enable {
    ${namespace}.services.networking.caddy.hosts = {
      "https://${config.networking.hostName}:443" = ''
        reverse_proxy http://[::1]:2000
      '';
    };

    services.glance = {
      enable = true;
      openFirewall = true;

      environmentFile = config.sops.templates."glance/secrets.env".path;

      settings = {
        server = {
          host = "0.0.0.0";
          port = 2000;
        };

        theme = {
          # Teal city predefined theme (https://github.com/glanceapp/glance/blob/main/docs/themes.md#teal-city)
          background-color = "225 14 15";
          primary-color = "157 47 65";
          contrast-multiplier = 1.1;
        };

        pages = [
          {
            name = "Home";
            columns = [
              {
                size = "small";
                widgets = [
                  {
                    type = "calendar";
                    first-day-of-the-week = "monday";
                  }
                ];
              }

              {
                size = "full";
                widgets = [
                  {
                    type = "monitor";
                    cache = "1m";
                    title = "Services";
                    sites = [
                      {
                        title = "Zitadel";
                        url = "https://auth.kruining.eu";
                        icon = "sh:zitadel";
                      }
                      {
                        title = "Forgejo";
                        url = "https://git.amarth.cloud/chris";
                        icon = "sh:forgejo";
                      }
                      {
                        title = "Vaultwarden";
                        url = "https://vault.kruining.eu";
                        icon = "sh:vaultwarden";
                      }
                    ];
                  }
                  {
                    type = "monitor";
                    cache = "1m";
                    title = "Observability";
                    sites = [
                      {
                        title = "Grafana";
                        url = "http://${config.networking.hostName}:${builtins.toString config.services.grafana.settings.server.http_port}";
                        icon = "sh:grafana";
                      }
                      {
                        title = "Prometheus";
                        url = "http://${config.networking.hostName}:${builtins.toString config.services.prometheus.port}";
                        icon = "sh:prometheus";
                      }
                    ];
                  }
                  {
                    type = "monitor";
                    cache = "1m";
                    title = "Media";
                    sites = [
                      {
                        title = "Jellyfin";
                        url = "http://${config.networking.hostName}:8096";
                        icon = "sh:jellyfin";
                      }
                      {
                        title = "Radarr";
                        url = "http://${config.networking.hostName}:${builtins.toString config.services.radarr.settings.server.port}";
                        icon = "sh:radarr";
                      }
                      {
                        title = "Sonarr";
                        url = "http://${config.networking.hostName}:${builtins.toString config.services.sonarr.settings.server.port}";
                        icon = "sh:sonarr";
                      }
                      {
                        title = "Lidarr";
                        url = "http://${config.networking.hostName}:${builtins.toString config.services.lidarr.settings.server.port}";
                        icon = "sh:lidarr";
                      }
                      {
                        title = "Prowlarr";
                        url = "http://${config.networking.hostName}:${builtins.toString config.services.prowlarr.settings.server.port}";
                        icon = "sh:prowlarr";
                      }
                      {
                        title = "qBittorrent";
                        url = "http://${config.networking.hostName}:${builtins.toString config.services.qbittorrent.webuiPort}";
                        icon = "sh:qbittorrent";
                      }
                      {
                        title = "SABnzbd";
                        url = "http://${config.networking.hostName}:${builtins.toString config.services.sabnzbd.settings.misc.port}";
                        icon = "sh:sabnzbd";
                      }
                    ];
                  }
                ];
              }

              {
                size = "small";
                widgets = [
                  {
                    type = "weather";
                    location = "Amsterdam, The Netherlands";
                    units = "metric";
                    hour-format = "24h";
                  }

                  {
                    type = "server-stats";
                    servers = [
                      {
                        type = "local";
                        name = "Ulmo";
                      }
                    ];
                  }
                ];
              }
            ];
          }
        ];
      };
    };

    sops.templates."glance/secrets.env" = {
      # owner = config.services.glance.user;
      # group = config.services.glance.group;
      content = ''
        RADARR_KEY="${config.sops.placeholder."radarr/apikey"}"
        SONARR_KEY="${config.sops.placeholder."sonarr/apikey"}"
        LIDARR_KEY="${config.sops.placeholder."lidarr/apikey"}"
      '';
    };
  };
}
