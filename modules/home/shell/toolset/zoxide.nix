{ config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.modules.${user}.shell.toolset.zoxide;
in
{
  options.modules.${user}.shell.toolset.zoxide = {
    enable = mkEnableOption "cd replacement";
  };

  config = mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = with pkgs; [ zoxide ];

      programs.zoxide = {
        enable = true;
      };
    };
  };
}
