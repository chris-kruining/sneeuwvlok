{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkDefault mkOption mkMerge;
  inherit (lib.types) nullOr enum;

  cfg = config.${namespace};
in
{
  options.${namespace} = {
    preset = mkOption {
      type = nullOr enum [ "server" "desktop" ];
      default = null;
      example = "desktop";
      description = "Which defaults profile to start with";
    };
  };

  config = mkMerge [
    (mkIf (cfg.preset == "desktop") {
      ${namespace} = mkDefault {
        hardware.has = {
          audio = true;
        };

        boot = {
          quiet = true;
          animated = true;
        };

        desktop.use = "kde";
      };
    })

    (mkIf (cfg.preset == "server") {
      ${namespace} = mkDefault {
        services = {
          ssh.enable = true;
        };
      };
    })
  ];
}
