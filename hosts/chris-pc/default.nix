{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware.nix ];

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

