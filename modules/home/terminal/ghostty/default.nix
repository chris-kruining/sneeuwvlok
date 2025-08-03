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
        background-blur-radius = 20;
        theme = "dark:stylix,light:stylix";
        window-theme = (config.${namespace}.themes.polarity or "dark");
        background-opacity = 0.8;
        minimum-contrast = 1.1;
      };
    };
  };
}
