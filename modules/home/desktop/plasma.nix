{ inputs, config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf;

  cfg = config.modules.${user}.desktop.plasma;
in
{
  options.modules.${user}.desktop.plasma = let
    inherit (lib.options) mkEnableOption mkOption;
  in {
    enable = mkEnableOption "plasma 6";

    autoLogin = mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Enable plasma's auto login feature.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs.kdePackages; [
      kcoreaddons
    ];

    # environment.plasma6.excludePackages = with pkgs.kdePackages; [ konsole kate ghostwriter oxygen ];
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    services = {
      xserver.enable = true;

      desktopManager.plasma6.enable = true;

      displayManager = {
        defaultSession = "plasma";
        sddm = {
          enable = true;
          wayland.enable = true;
        };
        autoLogin = mkIf cfg.autoLogin {
          enable = true;
          inherit user;
        };
      };
    };

    # should enable theme integration with gtk apps (i.e. firefox, thunderbird)
    programs.dconf.enable = true;

    home-manager = {
      sharedModules = [
        inputs.plasma-manager.homeManagerModules.plasma-manager
      ];
    };

    home-manager.users.${user}.programs.plasma = {
      enable = true;
      immutableByDefault = false;
      windows.allowWindowsToRememberPositions = true;

      workspace = {
        colorScheme = "CatppuccinMocha";
      };

      spectacle.shortcuts = {
        captureRectangularRegion = "Meta+Shift+S";
      };

      kwin = {
        edgeBarrier = 0;
        cornerBarrier = false;

        effects = {
          translucency.enable = true;

          blur = {
            enable = true;
            strength = 5;
            noiseStrength = 5;
          };

          snapHelper.enable = true;
        };
      };

      panels = [
        # Windows-like panel at the bottom
        {
          location = "bottom";
          widgets = [
            "org.kde.plasma.kickoff"
            {
              name = "org.kde.plasma.icontasks";
              config = {
                launchers = [
                  "preferred://browser"
                  "applications:org.kde.konsole.desktop"
                  "applications:org.kde.dolphin.desktop"
                  "applications:equibop.desktop"
                  "applications:code.desktop"
                  "applications:com.obsproject.Studio"
                  "applications:spotify.desktop"
                ];
              };
            }
            "org.kde.plasma.systemtray"
            "org.kde.plasma.digitalclock"
          ];
          floating = true;
          minLength = 1743;
          maxLength = 1920;
          hiding = "dodgewindows";
        }
      ];

      powerdevil = {
        AC = {
          powerButtonAction = "shutDown";
          whenLaptopLidClosed = "doNothing";

          autoSuspend.action = "nothing";
          dimDisplay.enable = false;

          turnOffDisplay = {
            idleTimeout = "never";
          };
        };
        battery = {
          powerButtonAction = "shutDown";
          whenLaptopLidClosed = "doNothing";

          autoSuspend.action = "nothing";
          dimDisplay.enable = false;

          turnOffDisplay = {
            idleTimeout = "never";
          };
        };
        lowBattery = {
          powerButtonAction = "shutDown";
          whenLaptopLidClosed = "doNothing";

          autoSuspend.action = "nothing";
          dimDisplay.enable = false;

          turnOffDisplay = {
            idleTimeout = "never";
          };
        };
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
        kdeglobals = {
          General = {
            # enable font antialiasing
            XftAntialias = true;
            XftHintStyle = "hintslight";
            XftSubPixel = "rgb";
          };
        };
        kwalletrc = {
          Wallet.Enabled = false;
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
