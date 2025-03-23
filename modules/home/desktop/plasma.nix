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

      users.${user}.programs.plasma = {
        enable = true;
        immutableByDefault = true;
        windows.allowWindowsToRememberPositions = true;

        workspace = {
          colorScheme = "CatppuccinMocha";
          wallpaper = config.stylix.image;
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
            floating = true;
            lengthMode = "fill";
            height = 32;
            hiding = "dodgewindows";
            screen = "all";
            widgets = [
              {
                kickoff = {
                  applicationsDisplayMode = "list";
                  compactDisplayStyle = false;
                  favoritesDisplayMode = "grid";
                  sortAlphabetically = true;
                  showButtonsFor = {
                    custom = [
                      "shutdown"
                      "reboot"
                      "logout"
                      "lock-screen"
                    ];
                  };
                  showActionButtonCaptions = true;
                };
              }
              {
                appMenu = {
                  compactView = false;
                };
              }
              {
                panelSpacer = {
                  expanding = true;
                };
              }
              {
                iconTasks = {
                  appearance = {
                    fill = false;
                    highlightWindows = true;
                    iconSpacing = "medium";
                    indicateAudioStreams = true;
                    rows = {
                        multirowView = "never";
                        maximum = null;
                    };
                    showTooltips = true;
                  };
                  behavior = {
                    grouping = {
                        clickAction = "showPresentWindowsEffect";
                        method = "byProgramName";
                    };
                                    minimizeActiveTaskOnClick = true;
                    newTasksAppearOn = "right";
                    showTasks = {
                        onlyInCurrentActivity = true;
                        onlyInCurrentDesktop = true;
                        onlyMinimized = false;
                        onlyInCurrentScreen = false;
                    };
                    sortingMethod = "manually";
                    unhideOnAttentionNeeded = true;
                    wheel = {
                        ignoreMinimizedTasks = true;
                        switchBetweenTasks = true;
                    };
                  };
                  launchers = [
                    "applications:org.kde.dolphin.desktop"
                    "preferred://browser"
                    "preferred://terminal"
                    "preferred://editor"
                    "applications:vesktop.desktop"
                    "applications:steam.desktop"
                  ];
                };
              }
              {
                panelSpacer = {
                  expanding = true;
                };
              }
              {
                systemTray = {
                  icons = {
                    scaleToFit = true;
                    spacing = "small";
                  };
                  items = {
                    hidden = [
                      "org.kde.plasma.brightness"
                    ];
                  };
                  pin = false;
                };
              }
              {
                digitalClock = {
                  date = {
                    enable = true;
                    format = "shortDate";
                    position = "belowTime";
                  };
                  time = {
                    format = "24h";
                    showSeconds = "onlyInTooltip";
                  };
                };
              }
            ];
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
  };
}
