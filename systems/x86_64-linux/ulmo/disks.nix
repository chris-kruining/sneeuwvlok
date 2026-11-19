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
      device = "/dev/disk/by-uuid/dd518f17-61c9-4831-b1bd-e1cc2af292aa";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/0A56-EBFE";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

    # The hdd, the media and ci-deps each have a folder of their own on it, bound where they are used
    "/mnt/data" = {
      device = "/dev/disk/by-label/data";
      fsType = "ext4";
    };

    "/var/media" = {
      device = "/mnt/data/media";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/mnt/data" ];
    };

    # The stores of the ci-deps repositories are tens of GB each and filled the ssd. Bound at the stores' own
    # location, the runners and the daemons don't know the difference
    "/var/lib/private/ci-deps-store" = {
      device = "/mnt/data/ci-deps";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/mnt/data" ];
    };
  };
}
