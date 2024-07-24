{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  modules = {
    themes.active = "everforest";

    networking.enable = true;

    services = {
      enable = true;
      media.enable = true;
    };

    desktop = {
      plasma.enable = true;

      terminal = {
        default = "alacritty";
        allacrity.enable = true;
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

