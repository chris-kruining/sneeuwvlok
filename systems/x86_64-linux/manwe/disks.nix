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
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

    "/home/chris/media" = {
      device = "ulmo:/";
      fsType = "nfs";
    };

    # "/home/chris/mandos" = {
    #   device = "mandos:/";
    #   fsType = "nfs";
    # };
  };
}
