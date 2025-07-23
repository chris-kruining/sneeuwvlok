{ lib, config, namespace, ... }:let
  inherit (lib) mkEnableOption mkOption;
  inherit (lib.types) bool;

  cfg = config.${namespace}.desktop.gnome;
in
{
  options.${namespace}.desktop.gnome = {
    enable = mkEnableOption "Enable Gnome";
  };

  config = mkIf cfg.enable {
  };
}
