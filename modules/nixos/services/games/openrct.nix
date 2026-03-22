{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.games.openrct;
in
{
  options.${namespace}.services.games.openrct = {
    enable = mkEnableOption "OpenRCT2";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      openrct2
    ];

    systemd.services.openrct = {
      enable = true;
      after = [ "network.target"];
      description = "OpenRCT2 Server";
      serviceConfig = {
        Type = "";
        ExecStart = lib.getExe pkgs.openrct2;
      };
    };
  };
}
