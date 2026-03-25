{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.terminal.ghostty;
in {
  options.sneeuwvlok.terminal.ghostty = {
    enable = mkEnableOption "enable ghostty";
  };

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      settings = {
        command = config.sneeuwvlok.defaults.shell;
        background-blur-radius = 20;
        theme = "dark:stylix,light:stylix";
        window-theme = config.sneeuwvlok.themes.polarity or "dark";
        background-opacity = 0.8;
        minimum-contrast = 1.1;
      };
    };
  };
}
