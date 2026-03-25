{ config, lib, pkgs, modulesPath, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel" ];
    kernelParams = [];
    extraModulePackages = [ ];
  };

  nixpkgs.hostPlatform = mkDefault pkgs.stdenv.hostPlatform.system;
  hardware.cpu.intel.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
}
