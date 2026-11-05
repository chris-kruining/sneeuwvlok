{ launchers, launcherButton }:
[
  {
    # the dock: pinned and open apps, only as wide as they need
    location = "bottom";
    floating = true;
    lengthMode = "fit";
    alignment = "center";
    height = 48;
    hiding = "none";
    screen = "all";
    widgets = [
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
          inherit launchers;
        };
      }
    ];
  }
  {
    # a thin bar on top with the (invisible) launcher, the clock in the middle and the tray on the right
    location = "top";
    floating = true;
    lengthMode = "fill";
    height = 30;
    hiding = "none";
    screen = "all";
    widgets = [
      {
        # appgrid in compact mode (meta): a focused search field with the session buttons, results show while typing.
        # meta needs it in a panel; its transparent button sits in the top-left corner and the spacer absorbs it
        name = "dev.xarbit.appgrid";
        config.General = {
          icon = "start-here-kde";
          useCustomButtonImage = true;
          customButtonImage = "file://${launcherButton}";
          hideGridWhenEmpty = true;
          showCategoryBar = false;
          showRecentApps = false;
          showDividers = false;
          headerActions = "lock:bar,logout:bar,sleep:bar,restart:bar,shutdown:bar,switchuser:off,updateCheck:off";
          headerActionsMigrated = true;
          powerButtonsMigrated = true;
          overrideRadius = true;
          cornerRadius = 6;
          openAnimation = 1;
          hoverAnimation = 0;
        };
      }
      {
        panelSpacer = {
          expanding = true;
        };
      }
      {
        digitalClock = {
          date = {
            enable = true;
            format.custom = "ddd dd MMM";
            position = "besideTime";
          };
          time = {
            format = "24h";
            showSeconds = "onlyInTooltip";
          };
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
    ];
  }
]
