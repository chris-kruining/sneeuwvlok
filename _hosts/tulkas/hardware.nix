{ config, lib, modulesPath, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/aa438c4c-d193-436b-91ca-c386c0688265";
      fsType = "ext4";
    };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/89B8-0702";
    fsType = "vfat";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/beddca5c-1ecc-4a46-9fc5-fd918eed8f2a"; }
  ];

  boot = {
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-amd" ];
    kernelParams = [];
    extraModulePackages = [ ];
  };

  nixpkgs.hostPlatform = mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
}
