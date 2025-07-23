{ lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.media;
in
{
  config.${namespace}.services.media = {
    enable = mkEnableOption "Enable media services";
  };

  config = mkIf cfg.enable {
    #=========================================================================
    # Dependencies
    #=========================================================================
    environment.systemPackages = with pkgs; [
      podman-tui
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
      jellyseerr
      mediainfo
      id3v2
      yt-dlp
    ];
    
    # need to permit these outdated packages until servarr finally upgrades at some point...
    permittedInsecurePackages = [
      "dotnet-sdk-6.0.428"
      "aspnetcore-runtime-6.0.36"
    ];

    #=========================================================================
    # Prepare system
    #=========================================================================
    users = {
      users.${user} = {
        isSystemUser = true;
        group = group;
      };
      groups.${group} = {};
    };

    systemd.tmpfiles.rules = [
      "d '${directory}/series' 0700 ${user} ${group} - -"
      "d '${directory}/movies' 0700 ${user} ${group} - -"
      "d '${directory}/music' 0700 ${user} ${group} - -"
      "d '${directory}/qbittorrent' 0700 ${user} ${group} - -"
      "d '${directory}/sabnzbd' 0700 ${user} ${group} - -"
      "d '${directory}/reiverr/config' 0700 ${user} ${group} - -"
      "d '${directory}/downloads/incomplete' 0700 ${user} ${group} - -"
      "d '${directory}/downloads/done' 0700 ${user} ${group} - -"
    ];

    #=========================================================================
    # Services
    #=========================================================================
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

      lanraragi = {
        enable = true;
        port = 6969;
      };

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
    };

    systemd.services.jellyfin.serviceConfig.killSignal = lib.mkForce "SIGKILL";

    modules.virtualisation.podman.enable = true;

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
            image = "ghcr.io/aleksilassila/reiverr:v2.2.0";
            autoStart = true;
            ports = [ "127.0.0.1:9494:9494" ];
            volumes = [ "${directory}/reiverr/config:/config" ];
          };
        };
      };
    };

    #=========================================================================
    # Hosting
    #=========================================================================
    services = {
      caddy = {
        enable = true;
        virtualHosts = {
          "media.kruining.eu".extraConfig = ''
            import auth

            reverse_proxy http://127.0.0.1:9494
          '';
          "jellyfin.kruining.eu".extraConfig = ''
            reverse_proxy http://127.0.0.1:8096
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 6969 ];
  };
}