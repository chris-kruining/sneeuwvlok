{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.thunderbird;
  themes = config.${namespace}.themes;
  t = themes.token;
  profile = config.snowfallorg.user.name;

  # its dark theme's colours, see chrome/classic/skin/classic/messenger/{layout,colors}.css in omni.ja
  colours = {
    layout-background-0 = "background";
    layout-background-1 = "surface";
    layout-background-2 = "surface";
    layout-background-3 = "surface-high";
    layout-background-4 = "surface-high";
    layout-color-0 = "foreground";
    layout-color-1 = "foreground";
    layout-color-2 = "foreground-dim";
    layout-color-3 = "outline";
    layout-border-0 = "surface-high";
    layout-border-1 = "outline";
    layout-border-2 = "outline";
    color-primary-default-dark = "accent";
    color-primary-hover-dark = "accent";
    color-primary-pressed-dark = "accent";
    color-primary-soft-dark = "accent-container";
    selected-item-color = "accent";
    selected-item-text-color = "on-accent";
    sidebar-background-color = "surface";
    tabs-toolbar-background-color = "background";
  };
in
{
  options.${namespace}.application.thunderbird = {
    enable = mkEnableOption "enable thunderbird";
  };

  config = mkIf cfg.enable {
    programs.thunderbird = {
      enable = true;
      package = pkgs.thunderbird-latest;

      profiles.${profile} = {
        isDefault = true;
        settings."toolkit.legacyUserProfileCustomizations.stylesheets" = themes.enable;
      };
    };

    # Read when it starts
    ${namespace}.themes.targets.thunderbird = mkIf themes.enable {
      path = ".thunderbird/${profile}/chrome/userChrome.css";
      text = ''
        :root {
        ${lib.concatStrings (lib.mapAttrsToList (n: v: "  --${n}: ${t v} !important;\n") colours)}}
      '';
    };

    accounts.email.accounts = {
      kruining = {
        primary = true;
        address = "chris@kruining.eu";
        realName = "Chris Kruining";
        imap = {
          host = "imap.kruining.eu";
          port = 993;
        };
        thunderbird = {
          enable = true;
          profiles = [ config.snowfallorg.user.name ];
        };
      };

      cgames = {
        primary = false;
        address = "chris@cgames.nl";
        realName = "Chris P Bacon";
        imap = {
          host = "imap.cgames.nl";
          port = 993;
        };
      };
    };
  };
}
