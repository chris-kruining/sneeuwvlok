{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption;
  inherit (lib.types) str;

  cfg = config.${namespace}.services.media.nextcloud;
in {
  options.${namespace}.services.media.nextcloud = {
    enable = mkEnableOption "Nextcloud";

    user = mkOption {
      type = str;
      default = "nextcloud";
    };

    group = mkOption {
      type = str;
      default = "nextcloud";
    };
  };

  config = mkIf cfg.enable {
    ${namespace}.services.networking.caddy = {
      hosts."cloud.kruining.eu" = ''
        php_fastcgi unix//run/phpfpm/nextcloud.sock {
          env front_controller_active true
        }
      '';
    };

    users = {
      users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
      };
      groups.${cfg.group} = {};
    };

    home-manager.users.${cfg.user}.home = {
      stateVersion = config.system.stateVersion;

      file.".netrc".text = ''
        login root
        password KaasIsAwesome!
      '';
    };

    services.nextcloud = {
      enable = true;
      # webserver = "caddy";
      package = pkgs.nextcloud31;
      hostName = "localhost";

      config = {
        adminpassFile = "/var/lib/nextcloud/admin-pass";
        dbtype = "sqlite";
      };
    };

    # systemd.user = {
    #   services.nextcloud-autosync = {
    #     Unit = {
    #       Description = "Automatic nextcloud sync";
    #       After = "network-online.target";
    #     };
    #     WantedBy = [ "multi-user.target" ];
    #     Service = {
    #       Type = "simple";
    #       ExecStart = "${pkgs.nextcloud-client}/bin/nextcloudcmd -h -n --path /var/media/music https://cloud.kruining.eu";
    #       TimeoutStopSec = "180";
    #       KillMode = "process";
    #       KillSignal = "SIGINT";
    #     };
    #   };

    #   timers.nextcloud-autosync = {
    #     Unit.Description = "Automatic nextcloud sync";
    #     Timer.OnBootSec = "5min";
    #     Timer.OnUnitActiveSec = "60min";
    #     Install.WantedBy = [ "multi-user.target" "timers.target" ];
    #   };

    #   startServices = true;
    # };
  };
}
