{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  modules = {
    themes = {
      enable = true;
      theme = "everforest";
      polarity = "dark";
    };

    networking.enable = true;

    services = {
      enable = true;
      media.enable = true;
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

