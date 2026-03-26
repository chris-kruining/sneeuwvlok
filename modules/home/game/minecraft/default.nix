{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.game.minecraft;
in {
  options.sneeuwvlok.game.minecraft = {
    enable = mkEnableOption "enable minecraft";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [prismlauncher];
  };
}
