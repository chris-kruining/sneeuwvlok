{ config, options, lib, pkgs, namespace, ... }:
let
  inherit (lib) attrValues mkIf mkMerge mkOption;
  inherit (lib.types) nullOr enum;

  cfg = config.${namespace}.editors;
in {
  options.${namespace}.editors = {
    default = mkOption {
      type = nullOr (enum [ "nano" "nvim" "zed" "kate" "vscodium" ]);
      default = "nano";
      description = "Default editor for text manipulation";
      example = "nvim";
    };
  };

  config = mkMerge [
    (mkIf (cfg.default != null) {
      home.sessionVariables = {
        EDITOR = cfg.default;
      };
    })
  ];
}
