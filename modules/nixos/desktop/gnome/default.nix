{ lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.desktop.gnome;
in
{
  options.${namespace}.desktop.gnome = {
    enable = mkEnableOption "Enable Gnome" // {
      default = (config.${namespace}.desktop.use == "gnome");
    };
  };

  config = mkIf cfg.enable {
  };
}
