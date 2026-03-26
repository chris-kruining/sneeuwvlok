{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  boot = {
    initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
    initrd.kernelModules = [];
    kernelModules = ["kvm-intel"];
    kernelParams = [];
    extraModulePackages = [];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
}
