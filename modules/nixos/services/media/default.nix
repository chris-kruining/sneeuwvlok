{
  pkgs,
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption;
  inherit (lib.types) str;

  cfg = config.${namespace}.services.media;
in {
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
      # "d '${cfg.path}/series' 0770 ${cfg.user} ${cfg.group} - -"
      # "d '${cfg.path}/movies' 0770 ${cfg.user} ${cfg.group} - -"
      # "d '${cfg.path}/music' 0770 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/qbittorrent' 0770 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/sabnzbd' 0770 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/downloads/incomplete' 0770 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/downloads/done' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    #=========================================================================
    # Services
    #=========================================================================
    services = {
      bazarr = {
        enable = true;
        openFirewall = true;
        user = cfg.user;
        group = cfg.group;
        listenPort = 2005;
      };

      flaresolverr = {
        enable = true;
        openFirewall = true;
        port = 2007;
      };

      # port is harcoded in nixpkgs module
      jellyfin = {
        enable = true;
        openFirewall = true;
        user = cfg.user;
        group = cfg.group;
      };

      postgresql = {
        enable = true;
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "jellyfin.kruining.eu".extraConfig = ''
            reverse_proxy http://[::1]:8096
          '';
        };
      };
    };

    systemd.services.jellyfin.serviceConfig.killSignal = lib.mkForce "SIGKILL";
  };
}
