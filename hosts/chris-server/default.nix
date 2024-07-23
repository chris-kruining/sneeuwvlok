{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  modules = {
    themes.active = "everforrest";

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
      toolset = {
        git.enable = true;
        gnupg.enable = true;
      };
    };
  };
}

