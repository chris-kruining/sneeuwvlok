{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.discord;
  themes = config.${namespace}.themes;
  t = themes.token;
in
{
  options.${namespace}.application.discord = {
    enable = mkEnableOption "enable discord (vesktop)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ vesktop ];

    # Vencord reloads its themes live. Discord's colours are its css variables, both the refreshed design's and the old
    ${namespace}.themes.targets.vesktop = mkIf themes.enable {
      path = ".config/vesktop/themes/sneeuwvlok.css";
      text = ''
        /**
         * @name Sneeuwvlok
         * @description The wallpaper's colours
         * @author sneeuwvlok
         */
        :root, .theme-dark, .theme-darker, .theme-midnight, .visual-refresh {
          --background-base-lowest: ${t "background"};
          --background-base-lower: ${t "background"};
          --background-base-low: ${t "surface"};
          --background-surface-high: ${t "surface"};
          --background-surface-higher: ${t "surface-high"};
          --background-surface-highest: ${t "surface-high"};
          --background-primary: ${t "background"};
          --background-secondary: ${t "surface"};
          --background-secondary-alt: ${t "surface-high"};
          --background-tertiary: ${t "background"};
          --background-floating: ${t "surface"};
          --chat-background-default: ${t "background"};
          --channeltextarea-background: ${t "surface"};
          --modal-background: ${t "surface"};
          --border-subtle: ${t "surface-high"};
          --text-default: ${t "foreground"};
          --text-normal: ${t "foreground"};
          --text-strong: ${t "foreground"};
          --text-muted: ${t "foreground-dim"};
          --header-primary: ${t "foreground"};
          --header-secondary: ${t "foreground-dim"};
          --channels-default: ${t "foreground-dim"};
          --interactive-normal: ${t "foreground-dim"};
          --interactive-hover: ${t "foreground"};
          --interactive-active: ${t "foreground"};
          --interactive-muted: ${t "outline"};
          --text-link: ${t "accent"};
          --brand-500: ${t "accent"};
          --brand-experiment: ${t "accent"};
        }
      '';
    };

    home.activation.vesktopTheme = mkIf themes.enable (inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      file="${config.xdg.configHome}/vesktop/settings/settings.json"
      run mkdir -p "$(dirname "$file")"
      [ -e "$file" ] || run ${pkgs.bash}/bin/bash -c 'echo "{}" > "$1"' _ "$file"
      run ${pkgs.bash}/bin/bash -c '${lib.getExe pkgs.jq} ".enabledThemes = ((.enabledThemes // []) + [\"sneeuwvlok.css\"] | unique)" "$1" > "$1.new" && mv "$1.new" "$1"' _ "$file"
    '');
  };
}
