{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.studio;
in
{
  options.${namespace}.application.studio = {
    enable = mkEnableOption "enable Bricklink Studio";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ studio ];
  };
}
