{ config, lib, pkgs, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf;

  cfg = config.modules.system.audio;
in
{
  options.modules.system.audio = let
    inherit (lib.options) mkEnableOption;
  in
  {
    enable = mkEnableOption "modern audio support";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # easyeffects
      sof-firmware
    ];

    security.rtkit.enable = true;

    services.pulseaudio.enable = false;
    services.pipewire = {
      enable = true;
      wireplumber.enable = true;
      pulse.enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };
    };
  };
}
