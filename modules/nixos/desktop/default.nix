{ lib, config, namespace, inputs, ... }:
let
  inherit (lib) mkIf mkOption mkEnableOption mkMerge;
  inherit (lib.types) nullOr enum;

  cfg = config.${namespace}.desktop;
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
  ];

  options.${namespace}.desktop = {
    use = mkOption {
      type = nullOr (enum [ "plasma" "gamescope" "gnome" ]);
      default = null;
      example = "plasma";
      description = "Which desktop to enable";
    };
  };

  config = mkMerge [
    ({
      services.displayManager = {
        enable = true;
      };
    })

    # (mkIf (cfg.use != null) {
    #   ${namespace}.desktop.${cfg.use}.enable = true;
    # })
  ];
}
