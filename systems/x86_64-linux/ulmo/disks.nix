{ config, lib, pkgs, modulesPath, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  # TODO :: Implement disko at some point

  swapDevices = [
    { device = "/dev/disk/by-uuid/0ddf001a-5679-482e-b254-04a1b9094794"; }
  ];

  boot.supportedFilesystems = [ "nfs" ];
  
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/dd518f17-61c9-4831-b1bd-e1cc2af292aa";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/0A56-EBFE";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

    "/var/media" = {
      device = "/dev/disk/by-label/data";
      fsType = "ext4";
    };
  };
}
