{ ... }:
{
  home.file.".netrc".text = ''
    login root
    password KaasIsAwesome!
  '';

  systemd.user = {
    services.nextcloud-autosync = {
      Unit = {
        Description = "Automatic nextcloud sync";
        After = "network-online.target";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.nextcloud-client}/bin/nextcloudcmd -h -n --path /var/music /home/chris/Music https://cloud.kruining.eu";
        TimeoutStopSec = "180";
        KillMode = "process";
        KillSignal = "SIGINT";
      };
      Install.WantedBy = [ "multi-user.target" ];
    };
    timers.nextcloud-autosync = {
      Unit.Description = "Automatic nextcloud sync";
      Timer.OnBootSec = "5min";
      Timer.OnUnitActiveSec = "60min";
      Install.WantedBy = [ "multi-user.target" "timers.target" ];
    };
  };
}
