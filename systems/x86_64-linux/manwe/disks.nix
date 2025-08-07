{ config, lib, pkgs, modulesPath, inputs, ... }:
let
  inherit (lib.modules) mkDefault;
in
{
  imports = [
    inputs.disko.nixosModules.disko
  ];

  config = {
    swapDevices = [];

    boot.supportedFilesystems = [ "nfs" ];

    disko.devices = {
      disk = {
        main = {
          device = "/dev/nvme0";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "100M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };
    
    fileSystems = {
      "/home/chris/media" = {
        device = "ulmo:/";
        fsType = "nfs";
      };

      "/home/chris/mandos" = {
        device = "mandos:/";
        fsType = "nfs";
      };
    };
  };
}
