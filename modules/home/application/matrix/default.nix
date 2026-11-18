{ config, lib, pkgs, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.matrix;
  themes = config.${namespace}.themes;
  t = themes.token;
in
{
  options.${namespace}.application.matrix = {
    enable = mkEnableOption "enable Matrix clients (Element and Fractal)";

    fractal.enable = mkEnableOption "Fractal next to Element" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    home.packages = mkIf cfg.fractal.enable [ pkgs.fractal ];

    programs.element-desktop = {
      enable = true;
    };

    # Element desktop lays this over its own config.json, when it starts. A theme picked in its settings wins over the
    # default. Fractal is libadwaita, it takes the GTK colours
    ${namespace}.themes.targets.element = mkIf themes.enable {
      path = ".config/Element/config.json";
      text = builtins.toJSON {
        default_theme = "custom-Sneeuwvlok";
        setting_defaults = {
          use_system_theme = false;
          custom_themes = [{
            name = "Sneeuwvlok";
            is_dark = true;
            colors = lib.mapAttrs (_: v: if builtins.isList v then map t v else t v) {
              accent-color = "accent";
              primary-color = "accent";
              warning-color = "error";
              sidebar-color = "background";
              roomlist-background-color = "surface";
              roomlist-text-color = "foreground-dim";
              roomlist-text-secondary-color = "foreground";
              roomlist-highlights-color = "surface-high";
              roomlist-separator-color = "outline";
              timeline-background-color = "background";
              timeline-text-color = "foreground";
              timeline-text-secondary-color = "foreground-dim";
              timeline-highlights-color = "surface";
              username-colors = [ "accent" "red" "orange" "yellow" "green" "cyan" "blue" "magenta" ];
              avatar-background-colors = [ "accent" "red" "orange" "yellow" "green" "cyan" "blue" "magenta" ];
            };
            # The colours above only reach the older parts, the room list, space bar and most of the newer ui take
            # these, Element's design tokens (compound)
            compound = lib.mapAttrs (_: t) {
              "--cpd-color-bg-canvas-default" = "background";
              "--cpd-color-bg-subtle-primary" = "surface-high";
              "--cpd-color-bg-subtle-secondary" = "surface";
              "--cpd-color-bg-action-tertiary-hovered" = "surface";
              "--cpd-color-bg-action-tertiary-selected" = "surface-high";
              "--cpd-color-bg-action-primary-rest" = "accent";
              "--cpd-color-bg-accent-rest" = "accent";
              "--cpd-color-text-primary" = "foreground";
              "--cpd-color-text-secondary" = "foreground-dim";
              "--cpd-color-text-action-accent" = "accent";
              "--cpd-color-text-on-solid-primary" = "on-accent";
              "--cpd-color-icon-primary" = "foreground";
              "--cpd-color-icon-secondary" = "foreground-dim";
              "--cpd-color-icon-tertiary" = "foreground-dim";
              "--cpd-color-icon-accent-primary" = "accent";
              "--cpd-color-icon-accent-tertiary" = "accent";
              "--cpd-color-icon-on-solid-primary" = "on-accent";
              "--cpd-color-border-accent-primary" = "accent";
              "--cpd-color-border-focused" = "accent";
              "--cpd-color-border-interactive-secondary" = "outline";
            };
          }];
        };
      };
    };
  };
}
