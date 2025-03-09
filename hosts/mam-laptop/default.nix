{ config, lib, pkgs, ... }:
{
  # imports = [ ./hardware.nix ];

  user_name = "moeke";
  # user = {
  #   name = "moeke";
  #   display_name = "Ons mam";
  # };

  modules = {
    themes = {
      enable = true;
      theme = "everforest";
      polarity = "light";
    };

    system.audio.enable = true;
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
        default = "chrome";
        chrome.enable=true;
      };
    };

    shell = {
      default = "zsh";
    };
  };
}
