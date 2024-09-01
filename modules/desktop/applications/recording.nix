{ options, config, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.desktop.applications.recording;
in
{
  options.modules.desktop.applications.recording = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Enable recording software (OBS Studio)";
  };

  config = mkIf cfg.enable
  {
    boot = {
      extraModulePackages = with config.boot.kernelPackages; [
        v4l2loopback
      ];

      extraModprobeConfig = ''
        options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
      '';
    };

    security.polkit.enable = true;

    user.packages = with pkgs; [
      obs-studio
      obs-studio-plugins.wlrobs
      obs-studio-plugins.obs-backgroundremoval
      obs-studio-plugins.obs-pipewire-audio-capture
    ];
  };
}
