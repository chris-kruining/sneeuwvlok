{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption types genAttrs concatStringsSep mapAttrsToList;

  cfg = config.${namespace}.application.teams;
  themes = config.${namespace}.themes;
  t = themes.token;

  css = ".config/teams-for-linux/sneeuwvlok.css";

  # Teams is fluent ui (v9), its colours are these variables on every `.fui-FluentProvider`. In its dark theme the
  # backgrounds get darker with the number, 6 is the lightest
  colours = {
    colorNeutralBackground1 = "surface";
    colorNeutralBackground1Hover = "surface-high";
    colorNeutralBackground1Pressed = "surface-high";
    colorNeutralBackground1Selected = "surface-high";
    colorNeutralBackground2 = "background";
    colorNeutralBackground2Hover = "surface";
    colorNeutralBackground2Pressed = "surface";
    colorNeutralBackground2Selected = "surface";
    colorNeutralBackground3 = "background";
    colorNeutralBackground3Hover = "surface";
    colorNeutralBackground3Pressed = "surface";
    colorNeutralBackground3Selected = "surface";
    colorNeutralBackground4 = "background";
    colorNeutralBackground4Hover = "surface";
    colorNeutralBackground4Pressed = "surface";
    colorNeutralBackground4Selected = "surface";
    colorNeutralBackground5 = "background";
    colorNeutralBackground6 = "surface-high";
    colorNeutralForeground1 = "foreground";
    colorNeutralForeground1Hover = "foreground";
    colorNeutralForeground1Pressed = "foreground";
    colorNeutralForeground1Selected = "foreground";
    colorNeutralForeground2 = "foreground";
    colorNeutralForeground2Hover = "foreground";
    colorNeutralForeground2Pressed = "foreground";
    colorNeutralForeground2BrandHover = "accent";
    colorNeutralForeground2BrandPressed = "accent";
    colorNeutralForeground2BrandSelected = "accent";
    colorNeutralForeground3 = "foreground-dim";
    colorNeutralForeground3Hover = "foreground";
    colorNeutralForeground4 = "foreground-dim";
    colorNeutralForegroundDisabled = "outline";
    colorNeutralForegroundOnBrand = "on-accent";
    colorNeutralStroke1 = "outline";
    colorNeutralStroke1Hover = "foreground-dim";
    colorNeutralStroke1Pressed = "foreground-dim";
    colorNeutralStroke1Selected = "foreground-dim";
    colorNeutralStroke2 = "surface-high";
    colorNeutralStroke3 = "surface-high";
    colorNeutralStrokeSubtle = "surface-high";
    colorNeutralStrokeAccessible = "foreground-dim";
    colorBrandBackground = "accent";
    colorBrandBackgroundHover = "accent";
    colorBrandBackgroundPressed = "accent";
    colorBrandBackgroundSelected = "accent";
    colorBrandBackground2 = "accent-container";
    colorBrandForeground1 = "accent";
    colorBrandForeground2 = "accent";
    colorBrandForegroundLink = "accent";
    colorBrandForegroundLinkHover = "accent";
    colorBrandForegroundLinkPressed = "accent";
    colorBrandForegroundLinkSelected = "accent";
    colorBrandStroke1 = "accent";
    colorBrandStroke2 = "accent-container";
    colorCompoundBrandForeground1 = "accent";
    colorCompoundBrandForeground1Hover = "accent";
    colorCompoundBrandForeground1Pressed = "accent";
    colorCompoundBrandBackground = "accent";
    colorCompoundBrandBackgroundHover = "accent";
    colorCompoundBrandBackgroundPressed = "accent";
    colorCompoundBrandStroke = "accent";
    colorCompoundBrandStrokeHover = "accent";
    colorCompoundBrandStrokePressed = "accent";
  };
in
{
  options.${namespace}.application.teams = {
    enable = mkEnableOption "the wallpaper's colours in Teams (teams-for-linux, which himmelblau's o365 launchers run)";

    profiles = mkOption {
      type = types.listOf types.str;
      default = [ "Teams" ];
      example = [ "Teams" "work" ];
      description = "The o365 launchers' `--profile`s that are Teams, each keeps its config in `~/.config/o365-profiles/<profile>`";
    };
  };

  config = mkIf (cfg.enable && themes.enable) {
    # Read when Teams loads. Its own dark theme follows the desktop's, these go over that
    ${namespace}.themes.targets.teams = {
      path = css;
      text = ''
        :root, .fui-FluentProvider {
        ${concatStringsSep "\n" (mapAttrsToList (n: v: "  --${n}: ${t v} !important;") colours)}
        }
      '';
    };

    # Read only, so a theme picked in its menu doesn't stick
    home.file = genAttrs (map (p: ".config/o365-profiles/${p}/config.json") cfg.profiles) (_: {
      text = builtins.toJSON {
        appearance = {
          cssLocation = "${config.home.homeDirectory}/${css}";
          followSystemTheme = true;
        };
      };
    });
  };
}
