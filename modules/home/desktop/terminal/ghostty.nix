{
  config,
  options,
  lib,
  pkgs,
  user,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
in {
  options.modules.${user}.desktop.terminal.ghostty = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "ghostty"; };

  config = mkIf config.modules.${user}.desktop.terminal.ghostty.enable {
    environment.systemPackages = [
      pkgs.ghostty
    ];

    modules.${user}.shell.toolset.tmux.enable = true;

    home-manager.users.${user}.programs.ghostty = {
      enable = true;
      settings = {
        background-blur-radius = 20;
        theme = "dark:everforest,light:everforest";
        window-theme = "dark";
        background-opacity = 0.8;
        minimum-contrast = 1.1;
      };
    };
  };
}
