{ config, lib, pkgs, user, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.shell.toolset.eza;
in
{
  options.${namespace}.shell.toolset.eza = {
    enable = mkEnableOption "system-monitor";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ eza ];

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
}
