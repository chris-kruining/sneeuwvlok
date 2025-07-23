{ config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.modules.${user}.shell.toolset.bat;
in
{
  options.modules.${user}.shell.toolset.bat = {
    enable = mkEnableOption "cat replacement";
  };

  config = mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = with pkgs; [ bat ];

      programs.bat = {
        enable = true;
      };
    };
  };
}
