[
  {
    location = "bottom";
    floating = true;
    lengthMode = "fill";
    height = 42;
    hiding = "none";
    screen = "all";
    widgets = [
      {
        panelSpacer = {
          expanding = true;
        };
      }
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
          launchers = [
            "preferred://filemanager"
            "preferred://browser"
            "preferred://terminalemulator"
            "preferred://email"
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
]