{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  modules = {
    themes.active = "everforrest";

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

