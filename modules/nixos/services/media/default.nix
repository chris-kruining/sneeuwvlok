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
      "d '${cfg.path}/series' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/movies' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/music' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/qbittorrent' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/sabnzbd' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/reiverr/config' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/downloads/incomplete' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/downloads/done' 0700 ${cfg.user} ${cfg.group} - -"
    ];

    #=========================================================================
    # Services
    #=========================================================================
    services = let
      arrService = {
        enable = true;
        openFirewall = true;

        settings = {
          auth.AuthenticationMethod = "External";
        };
      };

      withPort = port: service: service // { settings.server.Port = builtins.toString port; };

      withUserAndGroup = service: service  // {
        user = cfg.user;
        group = cfg.group;
      };
    in {
      radarr =
        arrService
        |> withPort 2001
        |> withUserAndGroup;

      sonarr =
        arrService
        |> withPort 2002
        |> withUserAndGroup;

      lidarr =
        arrService
        |> withPort 2003
        |> withUserAndGroup;
        
      prowlarr =
        arrService
        |> withPort 2004;

      bazarr = {
        enable = true;
        openFirewall = true;
        user = cfg.user;
        group = cfg.group;
        listenPort = 2005;
      };

      # port is harcoded in nixpkgs module
      jellyfin = {
        enable = true;
        openFirewall = true;
        user = cfg.user;
        group = cfg.group;
      };

      flaresolverr = {
        enable = true;
        openFirewall = true;
        port = 2007;
      };

      qbittorrent = {
        enable = true;
        openFirewall = true;
        webuiPort = 2008;

        serverConfig = {
          LegalNotice.Accepted = true;
        };

        user = cfg.user;
        group = cfg.group;
      };

      # port is harcoded in nixpkgs module
      sabnzbd = {
        enable = true;
        openFirewall = true;
        configFile = "${cfg.path}/sabnzbd/config.ini";

        user = cfg.user;
        group = cfg.group;
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
