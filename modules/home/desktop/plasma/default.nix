{ config, lib, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkOption genAttrs optional types head toList;

  cfg = config.${namespace}.desktop.plasma;
  osCfg = osConfig.${namespace}.desktop.plasma or { enable = false; };
  app = config.${namespace}.application;
in
{
  options.${namespace}.desktop.plasma = {
    launchers = mkOption {
      type = types.listOf types.str;
      default =
        [ "preferred://filemanager" "preferred://browser" "preferred://terminal" ]
        ++ optional app.thunderbird.enable "preferred://mailer"
        ++ optional app.discord.enable "applications:vesktop.desktop"
        ++ optional (app.steam.enable || osConfig.${namespace}.application.steam.enable or false) "applications:steam.desktop";
      defaultText = lib.literalMD "the file manager, browser and terminal, plus mail, discord and steam when they're enabled";
      example = [ "preferred://browser" "applications:steam.desktop" ];
      description = "The apps pinned to the taskbar, as `preferred://<filemanager|browser|terminal|mailer>` or `applications:<desktop file>`";
    };
  };

  config = mkIf osCfg.enable {
    # kde-gtk-config's kded module (part of plasma6's required packages, so it can't be excluded) rewrites the GTK
    # config as plain files whenever the look-and-feel is applied, which stylix does on every activation. It's loaded
    # on demand, so `autoload=false` doesn't stop it. Overwriting instead of backing up keeps activations from failing
    # on the backup of the previous rewrite
    gtk.gtk2.force = true;
    xdg.configFile = mkIf config.gtk.enable (
      genAttrs ["gtk-3.0/settings.ini" "gtk-3.0/gtk.css" "gtk-4.0/settings.ini" "gtk-4.0/gtk.css"] (_: {force = true;})
    );

    programs.plasma = {
      enable = true;

      immutableByDefault = true;
      windows.allowWindowsToRememberPositions = true;

      panels = import ./panels.nix { inherit (cfg) launchers; };
      powerdevil = import ./power.nix;

      kwin = {
        edgeBarrier = 0;
        cornerBarrier = false;
      };

      session = {
        general.askForConfirmationOnLogout = false;
        sessionRestore.restoreOpenApplicationsOnLogin = "onLastLogout";
      };

      workspace = {
        clickItemTo = "select";
        colorScheme = "Everforest";
        wallpaper = config.stylix.image;
      };

      spectacle.shortcuts = {
        captureRectangularRegion = "Meta+Shift+S";
      };

      kscreenlocker = {
        autoLock = false;
        lockOnResume = false;
        lockOnStartup = false;

        appearance = {
          alwaysShowClock = true;
          showMediaControls = true;
        };
      };

      configFile = {
        baloofilerc."Basic Settings"."Indexing-Enabled" = false;

        kdeglobals = {
          General = {
            # enable font antialiasing
            XftAntialias = true;
            XftHintStyle = "hintslight";
            XftSubPixel = "rgb";

            # used by `preferred://terminal` and "open terminal here", falls back to konsole when unset
            TerminalService = head (toList config.xdg.mimeApps.defaultApplications."x-scheme-handler/terminal");
          };
        };

        kwalletrc = {
          Wallet.Enabled = true;
        };

        plasmarc = {
          General = {
            RaiseMaximumVolume = true;
            VolumeStep = 2;
          };
        };

        kcminputrc = {
          Keyboard.NumLock.value = 0;
        };
      };
    };
  };
}
