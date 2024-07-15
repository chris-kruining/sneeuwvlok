{ config, pkgs, ... }:
{
  home = {
    username = "root";
    homeDirectory = "/home/root";
    stateVersion = "23.11"; # DO NOT CHANGE

    packages = [
    ];

    file = {
    };

    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  imports = [
    ../modules/home-manager/gpg.nix
    ../modules/home-manager/desktop.nix
    ../modules/home-manager/terminals/default.nix
  ];

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      userName = "Chris Kruining";
      userEmail = "chris@kruining.eu";

      ignores = [ "*~" "*.swp" ];
      aliases = {
        ci = "commit";
      };
      extraConfig = {};
    };

    lazygit.enable = true;
  };
}
