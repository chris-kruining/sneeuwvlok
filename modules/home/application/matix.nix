{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.matrix;
in {
  options.sneeuwvlok.application.matrix = {
    enable = mkEnableOption "enable Matrix client (Fractal)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [fractal element-desktop];

    programs.element-desktop = {
      enable = true;
    };
  };
}
