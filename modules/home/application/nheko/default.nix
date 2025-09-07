{ config, lib, pkgs, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.nheko;
in
{
  options.${namespace}.application.nheko = {
    enable = mkEnableOption "enable nheko (matrix client)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ nheko ];
  };
}
