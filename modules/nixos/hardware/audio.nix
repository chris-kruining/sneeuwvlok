{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.hardware.has.audio;
in {
  options.sneeuwvlok.hardware.has.audio = mkEnableOption "Enable bluetooth";

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
