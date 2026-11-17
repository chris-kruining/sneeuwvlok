{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.zen;
  themes = config.${namespace}.themes;
  t = themes.token;

  # Zen's profiles aren't declared here, so these go in every one there is (see the activation below)
  theme = ".local/share/sneeuwvlok/zen";
in
{
  imports = [
    inputs.zen-browser.homeModules.default
  ];

  options.${namespace}.application.zen = {
    enable = mkEnableOption "enable zen";
  };

  config = mkIf cfg.enable {
    # Both read when it starts. The accent is Zen's own setting, the rest overrides the colours it makes from it and
    # from the workspace's gradient
    ${namespace}.themes.targets = lib.mkIf themes.enable {
      zen-prefs = {
        path = "${theme}/user.js";
        text = ''
          user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
          user_pref("zen.theme.accent-color", "${t "accent"}");
        '';
      };
      zen-chrome = {
        path = "${theme}/userChrome.css";
        text = ''
          :root {
            --zen-primary-color: ${t "accent"} !important;
            --zen-colors-primary: ${t "surface-high"} !important;
            --zen-colors-secondary: ${t "surface"} !important;
            --zen-colors-tertiary: ${t "background"} !important;
            --zen-colors-border: ${t "outline"} !important;
            --zen-main-browser-background: ${t "background"} !important;
            --zen-themed-toolbar-bg: ${t "background"} !important;
            --toolbar-bgcolor: ${t "surface"} !important;
            --toolbar-color: ${t "foreground"} !important;
          }
        '';
      };
    };

    home.activation.zenTheme = lib.mkIf themes.enable (inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for profile in "$HOME"/.zen/*/ "${config.xdg.configHome}"/zen/*/; do
        [ -f "$profile/prefs.js" ] || continue
        for file in user.js chrome/userChrome.css; do
          if [ -e "$profile/$file" ] && [ ! -L "$profile/$file" ]; then
            warnEcho "not theming zen profile $profile, it has its own $file"
            continue
          fi
          run mkdir -p "$(dirname "$profile/$file")"
          run ln -sfn "$HOME/${theme}/$(basename "$file")" "$profile/$file"
        done
      done
    '');

    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };

    programs.zen-browser = {
      enable = true;

      policies = {
        AutofillAddressEnabled = true;
        AutofillCreditCardEnabled = false;

        AppAutoUpdate = false;
        DisableAppUpdate = true;
        ManualAppUpdateOnly = true;

        DisableFeedbackCommands = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;

        DontCheckDefaultBrowser = false;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };

        HttpAllowlist = [
          "http://ulmo"
        ];
      };

      policies.ExtensionSettings = let
        mkExtension = id: {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${builtins.toString id}/latest.xpi";
          installation_mode = "force_installed";
        };
      in
      {
        ublock_origin = 4531307;
        ghostry = 4562168;
        bitwarden = 4562769;
        sponsorblock = 4541835;
      };
    };
  };
}
