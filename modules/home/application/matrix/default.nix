{ config, lib, pkgs, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.matrix;
in
{
  options.${namespace}.application.matrix = {
    enable = mkEnableOption "enable Matrix clients (Element and Fractal)";

    fractal.enable = mkEnableOption "Fractal next to Element" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    home.packages = mkIf cfg.fractal.enable [ pkgs.fractal ];

    programs.element-desktop = {
      enable = true;
    };
  };
}
