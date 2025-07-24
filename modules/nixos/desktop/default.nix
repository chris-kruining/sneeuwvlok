{ lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkOption mkEnableOption mkMerge;
  inherit (lib.types) nullOr enum;

  cfg = config.${namespace}.desktop;
in
{
  options.${namespace}.desktop = {
    use = mkOption {
      type = nullOr (enum [ "plasma" "gamescope" "gnome" ]);
      default = null;
      example = "plasma";
      description = "Which desktop to enable";
    };

    autoLogin = mkEnableOption "Enable plasma's auto login feature.";
  };

  config = mkMerge [
    ({
      services.displayManager = {
        enable = true;

        autoLogin = mkIf cfg.autoLogin {
          enable = true;
        };
      };
    })

    (mkIf (cfg.use != null) {
      ${namespace}.desktop.${cfg.use}.enable = true;
    })
  ];
}
