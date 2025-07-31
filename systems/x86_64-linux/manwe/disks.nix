{ config, lib, pkgs, modulesPath, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  # TODO :: Implement disko at some point

  swapDevices = [];

  boot.supportedFilesystems = [ "nfs" ];
  
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/58272a1d-1b1d-4f42-b34a-bbc489f11022";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/BC59-C3D9";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

    "/home/chris/media" = {
      device = "ulmo:/";
      fsType = "nfs";
    };

    "/home/chris/mandos" = {
      device = "mandos:/";
      fsType = "nfs";
    };
  };
}
