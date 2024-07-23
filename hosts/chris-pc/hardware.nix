{ config, lib, pkgs, modulesPath, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/8c4eaf57-fdb2-4c4c-bcc0-74e85a1c7985";
      fsType = "ext4";
    };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/C842-316A";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/0ddf001a-5679-482e-b254-04a1b9094794"; }
  ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel" ];
    kernelParams = [];
    extraModulePackages = [ ];
  };

  networking.useDHCP = mkDefault true;

  nixpkgs.hostPlatform = mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;

  services = {
    power-profiles-deamon-enable = false;
    thermald.enable = false;
  };
}
