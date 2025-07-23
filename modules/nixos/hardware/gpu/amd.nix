{ pkgs, lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.hardware.has.gpu.amd;
in
{
  config.${namespace}.hardware.has.gpu.amd = mkEnableOption "Enable AMD gpu configuration";

  config = mkIf cfg {
    services.xserver.videoDrivers = [ "amd" ];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };

      amdgpu = {
        amdvlk = {
          enable = true;
          support32Bit.enable = true;
        };

        initrd.enable = true;
      };
    };
  };
}