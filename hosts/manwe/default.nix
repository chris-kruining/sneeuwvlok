{ config, lib, pkgs, ... }:
{
  fileSystems."/home/chris/games" = {
    device = "/dev/disk/by-label/games";
    fsType = "ext4";
  };

  fileSystems."/home/chris/data" = {
    device = "/dev/disk/by-label/Data";
    fsType = "ntfs-3g";
    options = [ "rw" "uid=chris" ];
  };

  modules = {
    system.audio.enable = true;

    # EXPERIMENTS
    services.auth.enable = true;

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
