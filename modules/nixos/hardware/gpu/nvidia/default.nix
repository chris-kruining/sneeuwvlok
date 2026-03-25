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

        # package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta;

        # package = let
        #   rcu_patch = pkgs.fetchpatch {
        #     url = "https://github.com/gentoo/gentoo/raw/c64caf53/x11-drivers/nvidia-drivers/files/nvidia-drivers-470.223.02-gpl-pfn_valid.patch";
        #     hash = "sha256-eZiQQp2S/asE7MfGvfe6dA/kdCvek9SYa/FFGp24dVg=";
        #   };
        # in config.boot.kernelPackages.nvidiaPackages.mkDriver {
        #   version = "550.40.07";
        #   sha256_64bit = "sha256-KYk2xye37v7ZW7h+uNJM/u8fNf7KyGTZjiaU03dJpK0=";
        #   sha256_aarch64 = "sha256-AV7KgRXYaQGBFl7zuRcfnTGr8rS5n13nGUIe3mJTXb4=";
        #   openSha256 = "sha256-mRUTEWVsbjq+psVe+kAT6MjyZuLkG2yRDxCMvDJRL1I=";
        #   settingsSha256 = "sha256-c30AQa4g4a1EHmaEu1yc05oqY01y+IusbBuq+P6rMCs=";
        #   persistencedSha256 = "sha256-11tLSY8uUIl4X/roNnxf5yS2PQvHvoNjnd2CB67e870=";

        #   patches = [ rcu_patch ];
        # };
      };
    };
  };
}
