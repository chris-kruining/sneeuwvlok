{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  fileSystems."/home/chris/games" = {
    device = "/dev/disk/by-label/games";
    fsType = "ext4";
  };

  fileSystems."/home/chris/data" = {
    device = "/dev/disk/by-label/Data";
    fsType = "ntfs-3g";
    options = [ "rw" "uid=chris" ];
  };

  networking.hostName = "chris-pc";

  modules = {
    themes = {
      enable = true;
      theme = "everforest";
      polarity = "dark";
    };

    system.audio.enable = true;
    networking.enable = true;

    develop = {
      rust.enable = true;
      js.enable = true;
      dotnet.enable = true;
    };

    services.games.minecraft.enable = true;

    desktop = {
      plasma.enable = true;
      type = "wayland";

#       games = {
#         minecraft.enable = false;
#       };

      applications = {
        communication.enable = true;
        email.enable = true;
        office.enable = true;
        steam.enable = true;
        recording.enable = true;
      };

      terminal = {
        default = "alacritty";
        alacritty.enable = true;
      };

      editors = {
        default = "nano";
        vscodium.enable = true;
        zed.enable = true;
        nvim.enable = true;
        nano.enable = true;
        kate.enable = true;
      };

      browsers = {
        default = "firefox";
        firefox.enable = true;
      };
    };

    shell = {
      default = "zsh";
      corePkgs.enable = true;
    };
  };
}
