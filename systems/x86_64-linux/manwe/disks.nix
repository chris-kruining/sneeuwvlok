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
    "/" = { device = "/dev/disk/by-uuid/8c4eaf57-fdb2-4c4c-bcc0-74e85a1c7985";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/C842-316A";
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
