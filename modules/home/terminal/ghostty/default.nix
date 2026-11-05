{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.terminal.ghostty;
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
        theme = "dark:stylix,light:stylix";
        window-theme = (config.${namespace}.themes.polarity or "dark");
        background-opacity = 1.0;
        minimum-contrast = 1.1;
        # kwin's decoration, so it gets the same frame and outline as every other window
        window-decoration = "server";
        # the palette made from the current wallpaper (plasma-wallpaper-rotate), when there is one
        config-file = "?${config.xdg.configHome}/ghostty/wallpaper";
      };
    };
  };
}
