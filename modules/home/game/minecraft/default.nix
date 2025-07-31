{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.game.minecraft;
in
{
  options.${namespace}.game.minecraft = {
    enable = mkEnableOption "enable minecraft";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ prismlauncher ];
  };
}
