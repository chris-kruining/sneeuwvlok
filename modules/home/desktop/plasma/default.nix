{
  config,
  lib,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf;

  cfg = config.sneeuwvlok.desktop.plasma;
  osCfg = osConfig.sneeuwvlok.desktop.plasma or {enable = false;};
in {
  options.sneeuwvlok.desktop.plasma = {
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
