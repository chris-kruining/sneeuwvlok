{ config, lib, pkgs, modulesPath, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  # TODO :: Implement disko at some point

  swapDevices = [
    { device = "/dev/disk/by-uuid/beddca5c-1ecc-4a46-9fc5-fd918eed8f2a"; }
  ];
  
  fileSystems = {
    "/" = { 
      device = "/dev/disk/by-uuid/aa438c4c-d193-436b-91ca-c386c0688265";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/89B8-0702";
      fsType = "vfat";
    };
  };
}
