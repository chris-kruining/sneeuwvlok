{ inputs, config, lib, pkgs, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.obs;
  themes = config.${namespace}.themes;
  t = themes.token;
  id = "com.sneeuwvlok.Yami.Sneeuwvlok";
in
{
  options.${namespace}.application.obs = {
    enable = mkEnableOption "enable obs";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      obs-studio
      obs-studio-plugins.wlrobs
      obs-studio-plugins.obs-backgroundremoval
      obs-studio-plugins.obs-pipewire-audio-capture
    ];

    # A variant of its own dark theme, like the ones it ships (share/obs/obs-studio/themes/Yami_*.ovt). Read when it starts
    ${namespace}.themes.targets.obs = mkIf themes.enable {
      path = ".config/obs-studio/themes/Sneeuwvlok.ovt";
      text = ''
        @OBSThemeMeta {
            name: 'Sneeuwvlok';
            id: '${id}';
            extends: 'com.obsproject.Yami';
            author: 'sneeuwvlok';
            dark: 'true';
        }

        @OBSThemeVars {
            --grey1: ${t "outline"};
            --grey2: ${t "outline"};
            --grey3: ${t "surface-high"};
            --grey4: ${t "surface-high"};
            --grey5: ${t "surface"};
            --grey6: ${t "surface"};
            --grey7: ${t "background"};
            --grey8: ${t "background"};

            --primary: ${t "accent-container"};
            --primary_light: ${t "accent"};
            --primary_lighter: ${t "accent"};
            --primary_dark: ${t "accent-container"};
            --primary_darker: ${t "surface-high"};

            --warning: ${t "yellow"};
            --danger: ${t "red"};
            --text: ${t "foreground"};
        }
      '';
    };

    # It saves its settings on exit, so this only picks the theme when it's closed
    home.activation.obsTheme = mkIf themes.enable (inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      file="${config.xdg.configHome}/obs-studio/user.ini"
      if [ -e "$file" ]; then
        run ${lib.getExe pkgs.crudini} --set "$file" Appearance Theme ${id}
      fi
    '');

    # boot = {
    #   extraModulePackages = with config.boot.kernelPackages; [
    #     v4l2loopback
    #   ];

    #   extraModprobeConfig = ''
    #     options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
    #   '';
    # };
  };
}
