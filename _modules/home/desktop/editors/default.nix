{
  config,
  options,
  lib,
  pkgs,
  user,
  ...
}: let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.modules.${user}.desktop.editors;
in {
  options.modules.${user}.desktop.editors = let
    inherit (lib.options) mkOption;
    inherit (lib.types) nullOr enum;
  in {
    default = mkOption {
      type = nullOr (enum [ "nano" "nvim" "zed" "kate" "vscodium" ]);
      default = "nano";
      description = "Default editor for text manipulation";
      example = "nvim";
    };
  };

  config = mkMerge [
    (mkIf (cfg.default != null) {
      home-manager.users.${user}.home.sessionVariables = {
        EDITOR = cfg.default;
      };
    })

    (mkIf (cfg.default == "nvim") {
      home-manager.users.${user}.home.packages = attrValues {
        inherit (pkgs) imagemagick editorconfig-core-c sqlite deno pandoc nuspell;
        inherit (pkgs.hunspellDicts) nl_NL en_GB-ise;
      };
    })
  ];
}
