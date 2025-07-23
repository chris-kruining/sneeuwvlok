{ pkgs, lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.hardware.has.gpu.nvidia;
in
{
  config.${namespace}.hardware.has.gpu.nvidia = mkEnableOption "Enable NVidia gpu configuration";

  config = mkIf cfg {
    services.xserver.videoDrivers = [ "nvidia" ];

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