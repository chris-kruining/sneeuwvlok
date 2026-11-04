{ config, lib, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf genAttrs;

  cfg = config.${namespace}.desktop.plasma;
  osCfg = osConfig.${namespace}.desktop.plasma or { enable = false; };
in
{
  options.${namespace}.desktop.plasma = {

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

      panels = import ./panels.nix;
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
        colorScheme = "EverforestDark";
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
