{ config, lib, pkgs, user, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) nullOr enum;

  cfg = config.modules.${user}.themes;
in {

  options.modules.${user}.themes = {
    enable = mkEnableOption "Theming (Stylix)";

    theme = mkOption {
      type = nullOr (enum [ "everforest" "catppuccin-latte" "chalk" ]);
      default = "everforest";
      description = "The theme to set the system to";
      example = "everforest";
    };

    polarity = mkOption {
      type = nullOr (enum [ "dark" "light" ]);
      default = "dark";
      description = "determine if system is in dark or light mode";
    };
  };

  config = mkIf (cfg.enable) {
    modules.theming.enable = true;

    stylix = {
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.theme}.yaml";
      image = ./${cfg.theme}.jpg;
      polarity = cfg.polarity;
      targets.qt.platform = "kde6";
    };
  };
}
