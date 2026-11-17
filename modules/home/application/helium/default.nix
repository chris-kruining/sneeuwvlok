{ inputs, system, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkMerge mkEnableOption concatStringsSep mapAttrsToList;

  cfg = config.${namespace}.application.helium;
  themes = config.${namespace}.themes;
  t = themes.token;

  # A theme is an extension, loaded from this folder on every start. Chromium writes its own `Cached Theme.pak` next to
  # the manifest, so only the manifest is a theme target and the folder is a real one
  theme = ".local/share/sneeuwvlok/helium-theme";

  colours = {
    frame = "background";
    frame_inactive = "background";
    frame_incognito = "surface";
    frame_incognito_inactive = "surface";
    background_tab = "background";
    background_tab_inactive = "background";
    toolbar = "surface";
    toolbar_text = "foreground";
    toolbar_button_icon = "foreground";
    tab_text = "foreground";
    tab_background_text = "foreground-dim";
    tab_background_text_inactive = "outline";
    bookmark_text = "foreground";
    omnibox_background = "background";
    omnibox_text = "foreground";
    ntp_background = "background";
    ntp_header = "surface";
    ntp_text = "foreground";
    ntp_link = "accent";
    button_background = "surface-high";
  };
in
{
  options.${namespace}.application.helium = {
    enable = mkEnableOption "enable helium";
  };

  # Helium reads chromium's policy and native messaging dirs under /etc, the system side (e.g. himmelblau's sso extension) goes there
  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [
        (inputs.helium.packages.${system}.helium.override (lib.optionalAttrs themes.enable {
          # Chromium only loads extensions from the command line with the feature that turns it off disabled
          commandLineArgs = "--load-extension=${config.home.homeDirectory}/${theme} --disable-features=DisableLoadExtensionCommandLineSwitch";
        }))
      ];
    }

    (mkIf themes.enable {
      # Takes effect on Helium's next start
      ${namespace}.themes.targets.helium = {
        path = "${theme}/manifest.json";
        text = ''
          {
            "manifest_version": 3,
            "name": "Sneeuwvlok",
            "version": "1",
            "theme": {
              "colors": {
                ${concatStringsSep ",\n" (mapAttrsToList (k: v: ''"${k}": [${t "${v}-rgb"}]'') colours)}
              }
            }
          }
        '';
        reload = ''rm -f "$HOME/${theme}/Cached Theme.pak"'';
      };
    })
  ]);
}
