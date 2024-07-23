{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  modules = {
    themes.active = "everforrest";

    networking.enable = true;

    develop = {
      rust.enable = true;
      js.enable = true;
      dotnet.enable = true;
    };

    desktop = {
      plasma.enable = true;
      type = "wayland";

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
      toolset = {
        git.enable = true;
        gnupg.enable = true;
      };
    };
  };
}

