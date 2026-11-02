{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption getExe;

  cfg = config.${namespace}.services.networking.awsvpnclient;
  package = pkgs.${namespace}.awsvpnclient;
in {
  options.${namespace}.services.networking.awsvpnclient = {
    enable = mkEnableOption "the official AWS VPN Client, for AWS Client VPN endpoints with saml";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [package];

    # Its dns script configures the tunnel's dns through systemd-resolved, networkmanager then hands dns to resolved as well
    services.resolved.enable = true;

    # Same as the unit in AWS's .deb
    systemd.services.aws-client-vpn-daemon = {
      description = "AWS VPN Client Daemon";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = getExe package.daemon;
        Restart = "always";
        RestartSec = "2s";
        TimeoutStopSec = "60s";
        RuntimeDirectory = "awsvpnclient";
        RuntimeDirectoryMode = "0755";
        StateDirectory = "awsvpnclient";
        StateDirectoryMode = "0700";
        LogsDirectory = "awsvpnclient";
      };
    };
  };
}
