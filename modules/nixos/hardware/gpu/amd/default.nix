{
  pkgs,
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.hardware.has.gpu;
in {
  options.sneeuwvlok.hardware.has.gpu.amd = mkEnableOption "Enable AMD gpu configuration";

  config = mkIf cfg.amd {
    services.xserver.videoDrivers = ["amd"];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };

      amdgpu = {
        initrd.enable = true;
      };
    };
  };
}
