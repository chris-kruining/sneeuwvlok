{ config, lib, pkgs, modulesPath, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-amd" ];
    kernelParams = [];
    extraModulePackages = [ ];
  };

  nixpkgs.hostPlatform = mkDefault pkgs.stdenv.hostPlatform.system;
  hardware.cpu.amd.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
}
