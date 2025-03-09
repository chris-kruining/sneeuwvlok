{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  fileSystems."/var/media_from_conf" = {
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
  };

  modules = {
    themes = {
      enable = true;
      theme = "everforest";
      polarity = "dark";
    };

    networking.enable = true;
    networking.ssh.enable = true;

    services = {
      enable = true;
      media.enable = true;

      games = {
        minecraft.enable = true;
      };
    };

    desktop = {
      type = "wayland";

      plasma.enable = true;

      terminal = {
        default = "alacritty";
        alacritty.enable = true;
      };

      editors = {
        default = "nano";
        nano.enable = true;
      };
    };

    shell = {
      default = "zsh";
      corePkgs.enable = true;
    };
  };
}
