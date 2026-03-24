{ config, lib, pkgs, modulesPath, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  # TODO :: Implement disko at some point

  swapDevices = [];

  boot.supportedFilesystems = [ "nfs" ];
  
  fileSystems = {
    "/" = { device = "/dev/disk/by-uuid/e60745c9-b3ea-4aeb-9c5c-b67ef1730826";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/42B3-C767";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };
}
