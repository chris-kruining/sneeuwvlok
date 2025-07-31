{ lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.hardware.has.bluetooth;
in
{
  options.${namespace}.hardware.has.bluetooth = mkEnableOption "Enable bluetooth";

  config = mkIf cfg {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
      };
    };
  };
}
