{ config, options, lib, pkgs, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf;

  cfg = config.modules.system.bluetooth;
in
{
  options.modules.system.bluetooth = let
    inherit (lib.options) mkEnableOption;
  in
  {
    enable = mkEnableOption "enable bluetooth";
  };

  config = mkIf cfg.enable {
    hardware = {
        bluetooth = {
            enable = true;
            powerOnBoot = true;
        };
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
