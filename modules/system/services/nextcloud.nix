{ config, lib, pkgs, ... }:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  user = "nextcloud";
in
{
  options.modules.services.nextcloud = {
    enable = mkEnableOption "Nextcloud";
  };

  config = mkIf config.modules.services.nextcloud.enable {
    users = {
      users.${user} = {
        name = user;
        isSystemUser = true;
        home = "/home/${user}";
        group = user;
      };
      groups.${user} = {};
    };

    home-manager.users.${user}.home.file.".netrc".text = ''
      login root
      password KaasIsAwesome!
    '';

    systemd.user = {
      services.nextcloud-autosync = {
        Unit = {
          Description = "Automatic nextcloud sync";
          After = "network-online.target";
        };
        WantedBy = [ "multi-user.target" ];
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.nextcloud-client}/bin/nextcloudcmd -h -n --path /var/music /home/${user}/Music https://cloud.kruining.eu";
          TimeoutStopSec = "180";
          KillMode = "process";
          KillSignal = "SIGINT";
        };
      };

      timers.nextcloud-autosync = {
        Unit.Description = "Automatic nextcloud sync";
        Timer.OnBootSec = "5min";
        Timer.OnUnitActiveSec = "60min";
        Install.WantedBy = [ "multi-user.target" "timers.target" ];
      };
    };

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
