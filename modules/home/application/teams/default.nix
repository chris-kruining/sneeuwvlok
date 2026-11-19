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
    colorNeutralBackground5Hover = "surface";
    colorNeutralBackground5Pressed = "surface";
    colorNeutralBackground5Selected = "surface";
    colorNeutralBackground6 = "surface-high";
    colorNeutralBackground7 = "surface";
    colorNeutralBackground7Hover = "surface-high";
    colorNeutralBackground7Pressed = "surface-high";
    colorNeutralBackground7Selected = "surface-high";
    colorNeutralBackground8 = "surface";
    colorNeutralBackgroundStatic = "surface";
    colorNeutralBackgroundDisabled = "surface";
    colorNeutralBackgroundDisabled2 = "surface";
    colorNeutralBackgroundAlpha = "surface";
    colorNeutralBackgroundAlpha2 = "surface-high";
    colorNeutralCardBackground = "surface";
    colorNeutralCardBackgroundHover = "surface-high";
    colorNeutralCardBackgroundPressed = "surface-high";
    colorNeutralCardBackgroundSelected = "surface-high";
    colorNeutralCardBackgroundDisabled = "surface";
    # the rest state stays transparent
    colorSubtleBackgroundHover = "surface-high";
    colorSubtleBackgroundPressed = "surface-high";
    colorSubtleBackgroundSelected = "surface-high";
    colorSubtleBackgroundLightAlphaHover = "surface-high";
    colorSubtleBackgroundLightAlphaPressed = "surface-high";
    colorSubtleBackgroundLightAlphaSelected = "surface-high";
    colorDefaultBackground7 = "background";
    # Teams' own, outside fluent's: the window, its title bar, the chat list and the message bubbles
    themeBackgroundColor = "background";
    themeLoadingScreenColor = "background";
    themeTitleBarBackgroundColor = "background";
    themeTitleBarButtonHoverBackgroundColor = "surface-high";
    preload-title-bar-background-color = "background";
    backgroundCanvas = "background";
    chat-list-backgroundItemHover = "surface-high";
    chat-list-backgroundItemActive = "surface-high";
    chat-list-backgroundActiveItemHover = "surface-high";
    chat-list-backgroundActiveItemActive = "surface-high";
    chatThemeIncomingBubbleBackground = "surface";
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
    # The rest of the brand colours Teams uses, the left rail's active app among them
    colorTeamsBrand1Hover = "accent";
    colorTeamsBrand1Pressed = "accent";
    colorTeamsBrand1Selected = "accent";
    colorNeutralForeground3BrandHover = "accent";
    colorNeutralForeground3BrandPressed = "accent";
    colorNeutralForeground3BrandSelected = "accent";
    colorBrandForeground2Hover = "accent";
    colorBrandForeground2Pressed = "accent";
    colorBrandForegroundInverted = "accent";
    colorBrandForegroundInvertedHover = "accent";
    colorBrandForegroundInvertedPressed = "accent";
    colorBrandForegroundOnLight = "accent";
    colorBrandForegroundOnLightHover = "accent";
    colorBrandForegroundOnLightPressed = "accent";
    colorBrandForegroundOnLightSelected = "accent";
    colorBrandBackground2Hover = "accent-container";
    colorBrandBackground2Pressed = "accent-container";
    colorBrandBackground3Static = "accent-container";
    colorBrandBackground4Static = "accent-container";
    colorBrandBackgroundStatic = "accent";
    colorBrandBackgroundInverted = "accent";
    colorBrandBackgroundInvertedHover = "accent";
    colorBrandBackgroundInvertedPressed = "accent";
    colorBrandBackgroundInvertedSelected = "accent";
    colorBrandStroke2Hover = "accent";
    colorBrandStroke2Pressed = "accent";
    colorBrandStroke2Contrast = "accent";
    colorNeutralStrokeOnBrand = "background";
    colorNeutralStrokeOnBrand2 = "background";
    colorNeutralStrokeOnBrand2Hover = "background";
    colorNeutralStrokeOnBrand2Pressed = "background";
    colorNeutralStrokeOnBrand2Selected = "background";
  };

  # Your own message bubble doesn't take the variables in every chat theme: in the default one it is a fixed indigo
  # (Teams' atomic classes, named after their css, so they hold until Microsoft changes that colour)
  myBubbleClasses = [ "fypbzun" "f1prliu4" "f1sqoi2t" "f1zh9pu" "fqpc6vf" "f1s4jey1" "f1l1o5cc" ];

  # Your own message bubble is a `background-image`, Teams' accent gradient, so it takes a gradient and not a colour
  myBubble = {
    background = [ "globalAccentMyBubbleBackground" "chatThemeMyBubbleBackground" ];
    foreground = [ "globalAccentMyBubbleForeground" "chatThemeMyBubbleForeground" ];
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
        :root, body, .fui-FluentProvider {
        ${concatStringsSep "\n" (mapAttrsToList (n: v: "  --${n}: ${t v} !important;") colours)}
        }

        /* Teams sets these per chat theme, in the style of the chat it is in */
        :root, body, .fui-FluentProvider, [style*="MyBubble"] {
        ${concatStringsSep "\n" (map (n: "  --${n}: linear-gradient(${t "accent-container"}, ${t "accent-container"}) !important;") myBubble.background)}
        ${concatStringsSep "\n" (map (n: "  --${n}: ${t "on-accent-container"} !important;") myBubble.foreground)}
        }

        .fui-ChatMyMessage__body,
        ${concatStringsSep ",\n" (map (c: ".fui-ChatMyMessage .${c}") myBubbleClasses)} {
          background-image: none !important;
          background-color: ${t "accent-container"} !important;
          color: ${t "on-accent-container"} !important;
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
