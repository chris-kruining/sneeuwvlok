{ launchers }:
[
  {
    # the dock: the launcher with pinned and open apps, only as wide as they need
    location = "bottom";
    floating = true;
    lengthMode = "fit";
    alignment = "center";
    height = 48;
    hiding = "none";
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
    # a thin bar on top with the clock in the middle and the tray on the right
    location = "top";
    floating = true;
    lengthMode = "fill";
    height = 30;
    hiding = "none";
    screen = "all";
    widgets = [
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
