{ config, options, lib, pkgs, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge mkForce;
  inherit (lib.meta) getExe;

  user = "media";
  group = "media";
  directory = "/var/media";
in
{
  options.modules.services.media = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Media tools";
  };

  config = mkIf config.modules.services.media.enable {
    environment.systemPackages = with pkgs; [
      podman-tui
      jellyfin
      jellyseerr
      mediainfo
    ];

    users = {
      users."${user}" = {
        isSystemUser = true;
        group = group;
      };
      groups."${group}" = {};
    };

    system.activationScripts.var = mkForce ''
      install -d -m 0755 -o ${user} -g ${group} ${directory}/series
      install -d -m 0755 -o ${user} -g ${group} ${directory}/movies
      install -d -m 0755 -o ${user} -g ${group} ${directory}/qbittorrent
      install -d -m 0755 -o ${user} -g ${group} ${directory}/sabnzbd
      install -d -m 0755 -o ${user} -g ${group} ${directory}/reiverr/config
      install -d -m 0755 -o ${user} -g ${group} ${directory}/downloads/incomplete
      install -d -m 0755 -o ${user} -g ${group} ${directory}/downloads/done
    '';

    services = let
      serviceConf = {
        enable = true;
        openFirewall = true;
        user = user;
        group = group;
      };
    in {
      jellyfin = serviceConf;
      radarr = serviceConf;
      sonarr = serviceConf;
      bazarr = serviceConf;
      lidarr = serviceConf;

      jellyseerr = {
        enable = true;
        openFirewall = true;
      };

      prowlarr = {
        enable = true;
        openFirewall = true;
      };

      qbittorrent = {
        enable = true;
        openFirewall = true;
        dataDir = "${directory}/qbittorrent";
        port = 5000;

        user = user;
        group = group;
      };

      sabnzbd = {
        enable = true;
        openFirewall = true;
        configFile = "${directory}/sabnzbd/config.ini";

        user = user;
        group = group;
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "media.kruining.eu".extraConfig = ''
            reverse_proxy http://127.0.0.1:9494
          '';
          "series.kruining.eu".extraConfig = ''
            reverse_proxy http://127.0.0.1:8989
          '';
          "movies.kruining.eu".extraConfig = ''
            reverse_proxy http://127.0.0.1:7878
          '';
          "jellyfin.kruining.eu".extraConfig = ''
            reverse_proxy http://127.0.0.1:8096
          '';
          "cloud.kruining.eu".extraConfig = ''
            php_fastcgi unix//run/phpfpm/nextcloud.sock {
              env front_controller_active true
            }
          '';
        };
      };
    };

    modules.virtualisation = {
      enable = true;
      podman.enable = true;
    };

    virtualisation = {
      oci-containers = {
        backend = "podman";

        containers = {
          flaresolverr = {
            image = "flaresolverr/flaresolverr";
            autoStart = true;
            ports = [ "127.0.0.1:8191:8191" ];
          };

          reiverr = {
            image = "ghcr.io/aleksilassila/reiverr:v2.0.0-alpha.6";
            autoStart = true;
            ports = [ "127.0.0.1:9494:9494" ];
            volumes = [ "${directory}/reiverr/config:/config" ];
          };
        };
      };
    };

    systemd.services.jellyfin.serviceConfig.killSignal = lib.mkForce "SIGKILL";
  };
}
