{ config, pkgs, ... }:
{
  fileSystems = {
    "/home/chris/games" = {
      device = "/dev/disk/by-label/games";
      fsType = "ext4";
    };

    "/home/chris/data" = {
      device = "/dev/disk/by-label/Data";
      fsType = "ntfs-3g";
      options = [ "rw" "uid=chris" ];
    };
  };

  modules = {
    boot = {
      silentBoot = true;
      animatedBoot = true;
    };

    desktop.gaming.enable = true;

    system.audio.enable = true;

    root = {
      user = {
        full_name = "__ROOT__";
        email = "__ROOT__@${config.networking.hostName}";
      };

      shell = {
        default = "zsh";
      };
    };
  };
}
