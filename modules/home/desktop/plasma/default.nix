{ config, lib, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.desktop.plasma;
  osCfg = osConfig.${namespace}.desktop.plasma or { enable = false; };
in
{
  options.${namespace}.desktop.plasma = {

  };

  config = mkIf osCfg.enable {
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

        # kde-gtk-config's kded module rewrites .gtkrc-2.0 and gtk-3.0/gtk.css as plain files, which breaks the next
        # home-manager activation. Stylix's kded5rc for this only arrives through XDG_CONFIG_DIRS, which kded6 often
        # doesn't get, and the package can't be excluded since it's in plasma6's required packages
        kded5rc."Module-gtkconfig".autoload = false;

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
