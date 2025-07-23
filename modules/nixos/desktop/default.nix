{ lib, config, namespace, ... }:let
  inherit (lib) mkIf mkOption mkEnableOption mkMerge attrNames filterAttrs readDir;
  inherit (lib.types) nullOr enum;

  cfg = config.${namespace}.desktop;
in
{
  options.${namespace}.desktop = {
    use = mkOption {
      type = nullOr enum (attrNames (filterAttrs (n: type: type == "directory") (readDir ./.)));
      default = null;
      example = "plasma";
      description = "Which desktop to enable";
    };

    autoLogin = mkEnableOption "Enable plasma's auto login feature.";
  };

  config = mkMerge [
    (mkIf cfg.desktop != null {
      "${namespace}".desktop.${cfg.use}.enable = true;

      services.displayManager = {
        enable = true;

        autoLogin = mkIf cfg.autoLogin {
          enable = true;
        };
      };
    })
  ];
}
