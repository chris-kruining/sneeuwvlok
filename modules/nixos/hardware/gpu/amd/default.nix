{ lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.hardware.has.gpu;
in
{
  options.${namespace}.hardware.has.gpu.amd = mkEnableOption "Enable AMD gpu configuration";

  config = mkIf cfg.amd {
    # `amdgpu` is the X11 driver for AMD cards. It is commented out because it
    # only affects X11 sessions, and the AMD machines run Wayland desktops with
    # `services.xserver.enable = false`, so setting it changes nothing.
    # Re-enable it if one of them ever runs an X11 session.
    # services.xserver.videoDrivers = [ "amdgpu" ];

    hardware = {
      graphics = {
        enable = true;
      };

      amdgpu = {
        initrd.enable = true;
      };
    };
  };
}
