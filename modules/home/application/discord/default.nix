{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.discord;
in
{
  options.${namespace}.application.discord = {
    enable = mkEnableOption "enable discord (vesktop)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ vesktop ];
  };
}
