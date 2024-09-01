{ config, options, lib, pkgs, ... }:
let
  inherit (builtins) getEnv map;
  inherit (lib.attrsets) attrValues mapAttrsToList;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.strings) concatStringsSep optionalString;

  cfg = config.modules.themes;
  desktop = config.modules.desktop;
in {
  options.modules.themes = let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.types) nullOr enum;
  in {
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
          package = pkgs.dejavu_fonts;
          name = "DejaVu Sans Mono";
        };

        emoji = {
          package = pkgs.noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
}
