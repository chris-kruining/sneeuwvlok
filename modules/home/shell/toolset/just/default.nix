{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.shell.toolset.just;
in
{
  options.${namespace}.shell.toolset.just = {
    enable = mkEnableOption "version-control system";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ just gum ];
  };
}
