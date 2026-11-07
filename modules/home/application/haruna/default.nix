{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.haruna;
in
{
  options.${namespace}.application.haruna = {
    enable = mkEnableOption "enable haruna";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ haruna ];
  };
}
