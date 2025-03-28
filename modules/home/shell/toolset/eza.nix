{ config, options, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.options) mkEnableOption;

  cfg = config.modules.${user}.shell.toolset.eza;
in
{
  options.modules.${user}.shell.toolset.eza = {
    enable = mkEnableOption "system-monitor";
  };

  config = mkIf cfg.enable {
    home-manager.users.${user} = {
      packages = with pkgs; [ eza ];

      programs.eza = {
        enable = true;
        icons = "auto";
        git = true;
        extraOptions = [
          "--hyperlink"
          "--across"
          "--group-directories-first"
        ];
      };
    };
  };
}
