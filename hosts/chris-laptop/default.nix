{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  modules = {
    themes.active = "everforrest";

    networking.enable = true;

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

      browsers = {
        default = "firefox";
        firefox.enable = true;
        firefox.privacy.enable = true;
      };
    };

    shell = {
      default = "zsh";
    };
  };

  programs.kdeconnect = {
    enable = true;
    package = pkgs.valent;
  };
}

