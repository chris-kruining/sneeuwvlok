{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption concatStringsSep mapAttrsToList;

  cfg = config.${namespace}.application.brickforge;
  themes = config.${namespace}.themes;
  t = themes.token;

  # BrickForge's design tokens (its design/tokens.json), the rest stay its dark theme's
  palette = {
    "surface.base" = "background";
    "surface.raised" = "surface";
    "surface.sunken" = "background";
    "surface.overlay" = "surface-high";
    "text.default" = "foreground";
    "text.muted" = "foreground-dim";
    "text.inverse" = "background";
    "text.on-accent" = "on-accent";
    "accent.default" = "accent";
    "accent.strong" = "accent";
    "accent.subtle" = "accent-container";
    "border.default" = "surface-high";
    "border.strong" = "outline";
    "focus" = "accent";
    "state.danger" = "red";
    "state.warning" = "yellow";
    "state.success" = "green";
    "state.info" = "blue";
    # A level up from the frame, so the view stands apart from what is around it
    "scene.viewport.background" = "surface";
    "scene.viewport.text" = "foreground";
    "scene.selection.outline" = "accent";
  };
in
{
  options.${namespace}.application.brickforge = {
    enable = mkEnableOption "BrickForge";
  };

  config = mkIf cfg.enable {
    programs.brickforge.enable = true;

    # BrickForge watches its config.toml, so pointing the link at another scheme's recolours it. Being a link it is
    # managed to BrickForge: quick settings shows the theme as set by the system and never writes the file
    ${namespace}.themes.targets.brickforge = mkIf themes.enable {
      path = ".config/brickforge/config.toml";
      text = ''
        [appearance.palette]
        base = "dark"
        ${concatStringsSep "\n" (mapAttrsToList (n: v: ''"${n}" = "${t v}"'') palette)}
      '';
    };
  };
}
