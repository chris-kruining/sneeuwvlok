{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.terminal.ghostty;
  fonts = config.${namespace}.themes.fonts;
  t = config.${namespace}.themes.token;
in
{
  options.${namespace}.terminal.ghostty = {
    enable = mkEnableOption "enable ghostty";
  };

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      settings = {
        command = config.${namespace}.defaults.shell;
        font-family = [ fonts.monospace.name fonts.emoji.name ];
        font-size = fonts.sizes.terminal;
        window-theme = "dark";
        background-opacity = 1.0;
        minimum-contrast = 1.1;
        # kwin's decoration, so it gets the same frame and outline as every other window
        window-decoration = "server";
        confirm-close-surface = false;
        # the colours, from the themes module (see below)
        config-file = "?${config.xdg.configHome}/ghostty/colors";
        # Ghostty only passes its light/dark state on to the terminal (the scheme apps query with `CSI ?996n`, like
        # copilot) when the config has a conditional theme, otherwise programs are always told it's light. That
        # takes two different themes, these are empty, the colors still come from the config above
        theme = "light:scheme-light,dark:scheme-dark";
      };
      themes = {
        scheme-light = {};
        scheme-dark = {};
      };
    };

    ${namespace}.themes.targets.ghostty = {
      path = ".config/ghostty/colors";
      text = ''
        background = ${t "background"}
        foreground = ${t "foreground"}
        cursor-color = ${t "accent"}
        selection-background = ${t "accent-container"}
        selection-foreground = ${t "on-accent-container"}
      '' + lib.concatImapStrings (i: c: "palette = ${toString (i - 1)}=${t c}\n") [
        "surface" "red" "green" "yellow" "blue" "magenta" "cyan" "foreground-dim"
        "outline" "red" "green" "yellow" "blue" "magenta" "cyan" "foreground"
      ];
      # SIGUSR2 reloads its config. Never anything that waits on it: at login ghostty's start job is queued behind
      # plasma-workspace.target, which waits for the wallpaper rotation, so waiting deadlocks the session start
      reload = "pkill -USR2 -f '/bin/ghostty( |$)'";
    };
  };
}
