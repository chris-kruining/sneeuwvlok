{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption;
  inherit (lib.types) str;

  cfg = config.sneeuwvlok.services.media;
in {
  imports = [
    ./glance
    ./jellyfin
    ./mydia
    ./nextcloud
    ./nfs
    ./servarr
  ];

  options.sneeuwvlok.services.media = {
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

      postgresql = {
        enable = true;
      };
    };
  };
}
