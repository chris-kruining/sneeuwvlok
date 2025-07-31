{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.shell.toolset.bat;
in
{
  options.${namespace}.shell.toolset.bat = {
    enable = mkEnableOption "cat replacement";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ bat ];

    programs.bat = {
      enable = true;
    };
  };
}
