{ config, lib, pkgs, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.matrix;
in
{
  options.${namespace}.application.matrix = {
    enable = mkEnableOption "enable Matrix client (Fractal)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ fractal ];
  };
}
