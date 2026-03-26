{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.hardware.has.gpu;
in {
  options.sneeuwvlok.hardware.has.gpu.nvidia = mkEnableOption "Enable NVidia gpu configuration";

  config = mkIf cfg.nvidia {
    services.xserver.videoDrivers = ["nvidia"];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };

      nvidia = {
        modesetting.enable = true;
        open = false;
        nvidiaSettings = true;

        powerManagement = {
          enable = true;
          finegrained = false;
        };
      };
    };
  };
}
