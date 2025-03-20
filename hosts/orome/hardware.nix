{ config, lib, pkgs, modulesPath, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/e60745c9-b3ea-4aeb-9c5c-b67ef1730826";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/42B3-C767";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel" ];
    kernelParams = [];
    extraModulePackages = [ ];
  };

  nixpkgs.hostPlatform = mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
}
