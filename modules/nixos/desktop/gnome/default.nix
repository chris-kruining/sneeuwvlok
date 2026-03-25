{
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.desktop.gnome;
in {
  options.sneeuwvlok.desktop.gnome = {
    enable =
      mkEnableOption "Enable Gnome"
      // {
        default = config.sneeuwvlok.desktop.use == "gnome";
      };
  };

  config =
    mkIf cfg.enable {
    };
}
