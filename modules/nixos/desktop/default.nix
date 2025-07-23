{ lib, config, namespace, ... }:let
  inherit (lib) mkOption mkMerge attrNames filterAttrs;
  inherit (lib.types) nullOr enum bool;

  cfg = config.${namespace}.desktop;
in
{
  options.${namespace}.desktop = {
    use = mkOption {
      type = nullOr enum (attrNames (filterAttrs (n: type == "directory") (readDir ./.)));
      default = null;
      example = "plasma";
      description = "Which desktop to enable";
    };

    autoLogin = mkOption {
      type = bool;
      default = false;
      example = true;
      description = "Enable plasma's auto login feature.";
    };
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
