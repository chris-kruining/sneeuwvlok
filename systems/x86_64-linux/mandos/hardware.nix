{ config, lib, pkgs, modulesPath, system, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel" ];
    kernelParams = [];
    extraModulePackages = [ ];
  };

  nixpkgs.hostPlatform = mkDefault system;
  hardware.cpu.intel.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
}
