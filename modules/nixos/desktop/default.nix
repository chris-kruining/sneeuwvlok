{
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkOption mkEnableOption mkMerge;
  inherit (lib.types) nullOr enum;

  cfg = config.sneeuwvlok.desktop;
in {
  imports = [
    ./cosmic
    ./gamescope
    ./gnome
    ./plasma
  ];

  options.sneeuwvlok.desktop = {
    use = mkOption {
      type = nullOr (enum ["plasma" "gamescope" "gnome" "cosmic"]);
      default = null;
      example = "plasma";
      description = "Which desktop to enable";
    };
  };

  config = mkMerge [
    {
      services.displayManager = {
        enable = true;
      };
    }

    # (mkIf (cfg.use != null) {
    #   sneeuwvlok.desktop.${cfg.use}.enable = true;
    # })
  ];
}
