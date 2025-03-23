{ config, lib, pkgs, user, ... }:
let
  inherit (lib) mkIf mkDefault;
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

    environment.sessionVariables = { QT_QPA_PLATFORMTHEME = "kde"; };

    home-manager.users.${user} = {
      xdg.configFile."menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

      qt = {
        enable = true;
        platformTheme.package = with pkgs.kdePackages; [
          plasma-integration
          systemsettings
        ];
        style = {
          package = pkgs.kdePackages.breeze;
          name = mkDefault "Breeze";
        };
      };
    };

    stylix = {
      enable = true;
      autoEnable = true;

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
