{ config, ... }:
{
  config = {
    fileSystems."/var/media" = {
      device = "/dev/disk/by-label/data";
      fsType = "ext4";
    };

    modules = {
      networking = {
        ssh.enable = true;
        nfs.enable = true;
      };

      services = {
        auth.enable = true;
        media.enable = true;
        nextcloud.enable = true;
      };

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
  };
}
