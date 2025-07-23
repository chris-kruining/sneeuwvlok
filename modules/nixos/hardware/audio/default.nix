{ pkgs, lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.hardware.has.audio;
in
{
  config.${namespace}.hardware.has.audio = mkEnableOption "Enable bluetooth";

  config = mkIf cfg {
    environment.systemPackages = with pkgs; [
      sof-firmware
    ];

    # https://wiki.nixos.org/wiki/PipeWire
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