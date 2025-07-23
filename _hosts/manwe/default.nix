{ config, ... }:
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

    "/home/chris/media" = {
      device = "ulmo:/";
      fsType = "nfs";
    };
  };

  boot.supportedFilesystems = [ "nfs" ];

  modules = {
    boot = {
      silentBoot = true;
      animatedBoot = true;
    };

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
