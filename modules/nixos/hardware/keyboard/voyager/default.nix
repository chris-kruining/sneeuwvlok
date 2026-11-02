{ lib, config, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.hardware.keyboard.voyager;
in
{
  options.${namespace}.hardware.keyboard.voyager = {
    enable = mkEnableOption "Enable tools for ZSA Voyager";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      keymapp
    ];

    # ZSA's own udev rules, for flashing and live training with keymapp and oryx, for whoever is logged in
    hardware.keyboard.zsa.enable = true;
  };
}
