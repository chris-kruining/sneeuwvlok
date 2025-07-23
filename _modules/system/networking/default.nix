{ config, options, lib, pkgs, ... }: let
  inherit (lib.modules) mkDefault;
  inherit (lib.options) mkOption;

  cfg = config.modules.networking;
in {
  options.modules.networking = {
    wifi.backend = mkOption {
      type = with lib.types; enum [ "wpa_supplicant" "iwd" ];
      default = "wpa_supplicant";
      example = "wpa_supplicant";
      description = "set the backend used for wifi wpa_supplicant by default";
    };
  };

  config = {
    systemd.services.NetworkManager-wait-online.enable = false;

    networking = {
      enableIPv6 = true;
      useDHCP = mkDefault true;

      firewall.enable = true;

      networkmanager = {
        enable = mkDefault true;
        wifi.backend = mkDefault config.modules.networking.wifi.backend;
      };
    };
  };
}
