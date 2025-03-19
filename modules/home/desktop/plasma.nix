{ config, options, lib, pkgs, user, ... }:
let
  inherit (lib.meta) getExe;
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
    services = {
      desktopManager.plasma6.enable = true;

      displayManager = {
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

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      konsole
    ];

    # should enable theme integration with gtk apps (i.e. firefox, thunderbird)
    programs.dconf.enable = true;

    home-manager.users.${user}.programs = {
      plasma = {
        enable = true;
        
        workspace = {
          lookAndFeel = "org.kde.breezedark.desktop";
          wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Patak/contents/images/1080x1920.png";
        };

        hotkeys.commands."spectable" = {
          name = "Launch Spectable";
          key = "Meta+Shift+S";
          command = "spectable captureRectangularRegion";
        };

        kwin = {
          edgeBarrier = 0;
          cornerBarrier = false;
        };

        panels = [
          # Windows-like panel at the bottom
          {
            location = "bottom";
            widgets = [
              # We can configure the widgets by adding the name and config
              # attributes. For example to add the the kickoff widget and set the
              # icon to "nix-snowflake-white" use the below configuration. This will
              # add the "icon" key to the "General" group for the widget in
              # ~/.config/plasma-org.kde.plasma.desktop-appletsrc.
              {
                name = "org.kde.plasma.kickoff";
                config = {
                  General = {
                    icon = "nix-snowflake-white";
                    alphaSort = true;
                  };
                };
              }
              # Or you can configure the widgets by adding the widget-specific options for it.
              # See modules/widgets for supported widgets and options for these widgets.
              # For example:
              {
                kickoff = {
                  sortAlphabetically = true;
                  icon = "nix-snowflake-white";
                };
              }
              # Adding configuration to the widgets can also for example be used to
              # pin apps to the task-manager, which this example illustrates by
              # pinning dolphin and konsole to the task-manager by default with widget-specific options.
              {
                iconTasks = {
                  launchers = [
                    "applications:org.kde.dolphin.desktop"
                    "applications:org.kde.konsole.desktop"
                  ];
                };
              }
              # Or you can do it manually, for example:
              {
                name = "org.kde.plasma.icontasks";
                config = {
                  General = {
                    launchers = [
                      "applications:org.kde.dolphin.desktop"
                      "applications:org.kde.konsole.desktop"
                    ];
                  };
                };
              }
              # If no configuration is needed, specifying only the name of the
              # widget will add them with the default configuration.
              "org.kde.plasma.marginsseparator"
              # If you need configuration for your widget, instead of specifying the
              # the keys and values directly using the config attribute as shown
              # above, plasma-manager also provides some higher-level interfaces for
              # configuring the widgets. See modules/widgets for supported widgets
              # and options for these widgets. The widgets below shows two examples
              # of usage, one where we add a digital clock, setting 12h time and
              # first day of the week to Sunday and another adding a systray with
              # some modifications in which entries to show.
              {
                digitalClock = {
                  calendar.firstDayOfWeek = "sunday";
                  time.format = "12h";
                };
              }
              {
                systemTray.items = {
                  # We explicitly show bluetooth and battery
                  shown = [
                    "org.kde.plasma.battery"
                    "org.kde.plasma.bluetooth"
                  ];
                  # And explicitly hide networkmanagement and volume
                  hidden = [
                    "org.kde.plasma.networkmanagement"
                    "org.kde.plasma.volume"
                  ];
                };
              }
            ];
          }
        ];

        configFile = {
          baloofilerc."Basic Settings"."Indexing-Enabled" = false;
          kwinrc."org.kde.kdecoration2".ButtonsOnLeft = "SF";
          kwinrc.Desktops.Number = {
            value = 1;
            immutable = true;
          };
          kscreenlockerrc = {
            Greeter.WallpaperPlugin = "org.kde.potd";
            # To use nested groups use / as a separator. In the below example,
            # Provider will be added to [Greeter][Wallpaper][org.kde.potd][General].
            "Greeter/Wallpaper/org.kde.potd/General".Provider = "bing";
          };
        };
      };
    };
  };
}
