{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.studio;
in
{
  options.${namespace}.application.studio = {
    enable = mkEnableOption "enable Bricklink Studio";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ studio ];
  };
}
