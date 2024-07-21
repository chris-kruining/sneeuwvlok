{
  config,
  options,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkDefault mkIf mkMerge;

  cfg = config.modules.networking;
in {
  options.modules.networking = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "network manager";
  };

  config =mkIf cfg.networkManager.enable {
    systemd.services.NetworkManager-wait-online.enable = false;

    networking = {
      firewall.enable = true;

      networkmanager = {
        enable = mkDefault true;
        wifi.backend = "wpa_supplicant";
      };
    };

    hm.services.network-manager-applet.enable = true;
  };
}
