{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  modules = {
    themes = {
      enable = true;
      theme = "everforest";
      polarity = "dark";
    };

    system.audio = true;
    networking.enable = true;

    desktop = {
      plasma.enable = true;

      terminal = {
        default = "alacritty";
        alacritty.enable = true;
      };

      editors = {
        default = "nano";
        nano.enable = true;
      };

      browsers = {
        default = "firefox";
        firefox.enable = true;
        firefox.privacy.enable = true;
      };
    };

    shell = {
      default = "zsh";
      corePkgs.enable = true;
    };
  };
}

