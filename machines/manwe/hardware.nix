{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  boot = {
    initrd.availableKernelModules = ["xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod"];
    initrd.kernelModules = [];
    kernelModules = ["kvm-amd"];
    kernelParams = [];
    extraModulePackages = [];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
}
