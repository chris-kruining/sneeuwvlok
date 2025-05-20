{ config, lib, pkgs, ... }:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  user = "nextcloud";
  group = "nextcloud";
in
{
  options.modules.services.nextcloud = {
    enable = mkEnableOption "Nextcloud";
  };

  config = mkIf config.modules.services.nextcloud.enable {
    users = {
      users.${user} = {
        isSystemUser = true;
        group = group;
      };
      groups.${group} = {};
    };

    home-manager.users.${user}.home = {
      stateVersion = config.system.stateVersion;

      file.".netrc".text = ''
        login root
        password KaasIsAwesome!
      '';
    };

    services.nextcloud = {
      enable = true;
      webserver = "caddy";
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

    services.caddy = {
      enable = true;
      virtualHosts."cloud.kruining.eu".extraConfig = ''
        php_fastcgi unix//run/phpfpm/nextcloud.sock {
          env front_controller_active true
        }
      '';
    };
  };
}
