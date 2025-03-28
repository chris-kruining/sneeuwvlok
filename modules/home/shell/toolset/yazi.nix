{ config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.modules.${user}.shell.toolset.yazi;
in
{
  options.modules.${user}.shell.toolset.yazi = {
    enable = mkEnableOption "cli file browser";
  };

  config = mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = with pkgs; [ yazi ];

      programs.yazi = {
        enable = true;
      };
    };
  };
}
