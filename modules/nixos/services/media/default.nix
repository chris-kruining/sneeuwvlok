{ pkgs, lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption;
  inherit (lib.types) str;

  cfg = config.${namespace}.services.media;
in
{
  options.${namespace}.services.media = {
    enable = mkEnableOption "Enable media services";

    user = mkOption {
      type = str;
      default = "media";
    };

    group = mkOption {
      type = str;
      default = "media";
    };

    path = mkOption {
      type = str;
      default = "/var/media";
    };
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
      users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
      };
      groups.${cfg.group} = {};
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.directory}/series' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.directory}/movies' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.directory}/music' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.directory}/qbittorrent' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.directory}/sabnzbd' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.directory}/reiverr/config' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.directory}/downloads/incomplete' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.directory}/downloads/done' 0700 ${cfg.user} ${cfg.group} - -"
    ];

    #=========================================================================
    # Services
    #=========================================================================
    services = let
      serviceConf = {
        enable = true;
        openFirewall = true;
        user = cfg.user;
        group = cfg.group;
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
        dataDir = "${cfg.directory}/qbittorrent";
        port = 5000;

        user = cfg.user;
        group = cfg.group;
      };

      sabnzbd = {
        enable = true;
        openFirewall = true;
        configFile = "${cfg.directory}/sabnzbd/config.ini";

        user = cfg.user;
        group = cfg.group;
      };

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
            volumes = [ "${cfg.directory}/reiverr/config:/config" ];
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 6969 ];
  };
}
