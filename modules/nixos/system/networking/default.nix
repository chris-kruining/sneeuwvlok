{ config, lib, pkgs, namespace, ... }: 
let
  inherit (lib) mkDefault;

  cfg = config.sneeuwvlok.system.networking;
in 
{
  options.sneeuwvlok.system.networking = {};

  config = {
    systemd.services.NetworkManager-wait-online.enable = false;

    networking = {
      enableIPv6 = true;
      useDHCP = mkDefault true;

      firewall.enable = true;

      networkmanager = {
        enable = true;
        wifi.backend = "wpa_supplicant";
      };
    };
  };
}
