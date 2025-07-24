{ config, lib, pkgs, user, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.shell.toolset.zoxide;
in
{
  options.${namespace}.shell.toolset.zoxide = {
    enable = mkEnableOption "cd replacement";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ zoxide ];

    programs.zoxide = {
      enable = true;
    };
  };
}
