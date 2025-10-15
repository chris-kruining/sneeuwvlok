{ config, lib, pkgs, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) nullOr enum;

  cfg = config.${namespace}.themes;
  osCfg = osConfig.${namespace}.theming;
in {
  options.${namespace}.themes = {
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
    stylix = {
      enable = true; 

      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.theme}.yaml";
      image = ./${cfg.theme}.jpg;
      polarity = cfg.polarity;
#      targets.qt.platform = mkDefault "kde";

      fonts = {
        serif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Serif";
        };

        sansSerif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Sans";
        };

        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font Mono";
        };

        emoji = {
          package = pkgs.noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
}
