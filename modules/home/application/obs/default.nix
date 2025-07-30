{ config, lib, pkgs, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.obs;
in
{
  options.${namespace}.application.obs = {
    enable = mkEnableOption "enable obs";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      obs-studio
      obs-studio-plugins.wlrobs
      obs-studio-plugins.obs-backgroundremoval
      obs-studio-plugins.obs-pipewire-audio-capture
    ];

    # boot = {
    #   extraModulePackages = with config.boot.kernelPackages; [
    #     v4l2loopback
    #   ];

    #   extraModprobeConfig = ''
    #     options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
    #   '';
    # };

    security.polkit.enable = true;
  };
}
