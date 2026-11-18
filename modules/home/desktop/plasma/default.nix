{ config, lib, pkgs, inputs, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkOption optional types head toList getExe concatMapStringsSep replaceStrings;

  cfg = config.${namespace}.desktop.plasma;
  osCfg = osConfig.${namespace}.desktop.plasma or { enable = false; };
  app = config.${namespace}.application;

  pmDir = "${config.xdg.dataHome}/plasma-manager";

  wallpapers = import ./wallpapers.nix;

  # meta only opens a launcher that lives in a panel, this transparent button keeps it invisible there
  launcherButton = pkgs.writeText "launcher-button.svg" ''<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1" viewBox="0 0 1 1"/>'';

  panels = import ./panels.nix { inherit (cfg) launchers; inherit launcherButton; };

  # kzones lays its zones over the whole screen, panels included, so this makes it use the area kwin maximizes windows
  # into instead. That area stops at the panels' edge, but floating panels sit 8px further in (and 8px from the screen
  # sides), so it's grown 2px sideways and shrunk 8px top and bottom: with the layouts' 10px padding windows end up 8px
  # from the screen sides like the panels, and 10px from each other and the panels. plasma de-floats a panel once a
  # window gets within its 8px float margin (+1), which the 10px keeps clear of.
  # Its per-screen layouts also all start at the first one whenever kwin starts, so the laptop panel starts on "Full".
  # It took layout 0 for "not set yet" too, which would keep resetting the laptop panel to "Full"
  kzones = pkgs.kdePackages.kzones.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/contents/ui/main.qml \
        --replace-fail \
          'clientArea = Workspace.clientArea(KWin.FullScreenArea, activeScreen, Workspace.currentDesktop);' \
          'const area = Workspace.clientArea(KWin.MaximizeArea, activeScreen, Workspace.currentDesktop);
          clientArea = Qt.rect(area.x - 2, area.y + 8, area.width + 4, area.height - 16);' \
        --replace-fail 'if (!screenLayout) {' 'if (screenLayout === undefined) {' \
        --replace-fail \
          'screenLayouts[Workspace.activeScreen.name] = 0' \
          'screenLayouts[Workspace.activeScreen.name] = Workspace.activeScreen.name.startsWith("eDP") ? 1 : 0'
    '';
  });

  kzonesLayouts = [
    {
      name = "Halves";
      padding = 10;
      zones = [
        { x = 0; y = 0; width = 50; height = 100; }
        { x = 50; y = 0; width = 50; height = 100; }
      ];
    }
    {
      name = "Full";
      padding = 10;
      zones = [ { x = 0; y = 0; width = 100; height = 100; } ];
    }
  ];

  # everything that follows the wallpaper is made at build time, the rotation only switches between them
  wallpaperThemes = pkgs.runCommand "wallpaper-themes" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./wallpaper-themes.py} ${getExe pkgs.matugen} ${pkgs.papirus-icon-theme}/share/icons $out \
      ${concatMapStringsSep " " (w: "${w.name}=${w.src}") wallpapers}
  '';

  # The boot splash shows the wallpaper of the day too. Plymouth only reads png, these are sized for the tallest screen
  splash = osConfig.${namespace}.boot.splash or { enable = false; };
  wallpaperSplashes = pkgs.runCommand "wallpaper-splashes" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    mkdir $out
    ${concatMapStringsSep "\n" (w: "magick ${w.src} -resize 'x1440>' -strip PNG24:$out/${w.name}.png") wallpapers}
  '';

  wallpaperRotate = pkgs.writeShellApplication {
    name = "plasma-wallpaper-rotate";
    runtimeInputs = with pkgs; [ kdePackages.plasma-workspace kdePackages.kconfig coreutils systemd ];
    text = replaceStrings [ "@themes@" "@apply@" "@changeicons@" "@splashes@" "@splash@" ] [
      "${wallpaperThemes}"
      (getExe config.${namespace}.themes.apply)
      "${pkgs.kdePackages.plasma-workspace}/libexec/plasma-changeicons"
      "${wallpaperSplashes}"
      (if splash.enable then splash.wallpaper else "")
    ] (builtins.readFile ./rotate.sh);
  };

  anurati = "${pkgs.${namespace}.anurati}/share/fonts/opentype/Anurati-Regular.otf";

  # The lock and logout screens' QML comes from the plasma shell package, so this is a copy of plasma-desktop's shell
  # with only those patched. It keeps the package name, because plasmashell names its config after it
  lockscreenShell = pkgs.runCommand "plasma-desktop-shell-lockscreen" { } ''
    cp -r ${pkgs.kdePackages.plasma-desktop}/share/plasma/shells/org.kde.plasma.desktop $out
    chmod -R u+w $out
    for screen in lockscreen logout; do
      cd $out/contents/$screen
      substitute ${./lockscreen/AestheticClock.qml} AestheticClock.qml \
        --subst-var-by anurati ${anurati} \
        --subst-var-by poppins ${pkgs.poppins}/share/fonts/truetype/Poppins-Light.ttf
    done
    patch -d $out/contents/lockscreen -p1 < ${./lockscreen/LockScreenUi.patch}
    patch -d $out/contents/logout -p1 < ${./lockscreen/Logout.patch}
    # the logout screen shows the wallpaper of the day, the splash's copy is the one place it's always at
    substituteInPlace $out/contents/logout/Logout.qml \
      --subst-var-by wallpaper "${if splash.enable then splash.wallpaper else ""}"
  '';

  # Plasma's own splash while the session starts, a look-and-feel package with only that in it: the login screen's
  # backdrop, so logging in doesn't pass through plasma's logo
  sessionSplash = pkgs.runCommand "plasma-splash-sneeuwvlok" { } ''
    mkdir -p $out/contents/splash
    cat > $out/metadata.json <<EOF
    {
      "KPackageStructure": "Plasma/LookAndFeel",
      "KPlugin": { "Id": "sneeuwvlok", "Name": "Sneeuwvlok", "Description": "The login screen staying put" }
    }
    EOF
    cd $out/contents/splash
    substitute ${./splash/Splash.qml} Splash.qml \
      --subst-var-by wallpaper "${if splash.enable then splash.wallpaper else ""}"
    substitute ${./lockscreen/AestheticClock.qml} AestheticClock.qml \
      --subst-var-by anurati ${anurati} \
      --subst-var-by poppins ${pkgs.poppins}/share/fonts/truetype/Poppins-Light.ttf
  '';

  fonts = config.${namespace}.themes.fonts;
  cursor = config.home.pointerCursor;
  font = f: size: { family = f.name; pointSize = size; };

  # plasma-manager's panel script makes a panel for every screen connected when it runs, and only runs again when it
  # changes. A screen connected later (the dock) stays without a panel, so this reruns it whenever a screen lacks one
  panelsFollowScreens = pkgs.writeShellApplication {
    name = "plasma-panels-follow-screens";
    runtimeInputs = with pkgs; [ kdePackages.qttools systemd coreutils gnused ];
    text = ''
      check() {
        missing=$(qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
          const covered = panels().map(p => p.screen);
          let missing = 0;
          for (let i = 0; i < screenCount; i++) if (!covered.includes(i)) missing++;
          print(missing);
        ' 2>/dev/null) || return 0

        if [ "$missing" != "" ] && [ "$missing" != 0 ]; then
          echo "$missing screen(s) without a panel, applying the panels again"
          rm -f "${pmDir}/last_run_desktop_script_panels"
          "${pmDir}/run_all.sh"
          # the panel script starts plasma's desktop config over, the wallpaper went with it
          systemctl --user start plasma-wallpaper-rotate.service
        fi
      }

      # Let plasma-manager's own autostart run first
      sleep 15
      check

      udevadm monitor --udev --subsystem-match=drm | while read -r line; do
        case "$line" in
          *change*)
            # A hotplug comes as a burst of events, and plasma needs a moment to add the screen
            sleep 5
            while read -r -t 1 _; do :; done
            check
            ;;
        esac
      done
    '';
  };
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
    home.packages = with pkgs; [
      darkly klassy kzones wallpaperThemes wallpaperRotate adw-gtk3
      inputs.appgrid.packages.${stdenv.hostPlatform.system}.default
    ];

    xdg.dataFile."plasma/shells/org.kde.plasma.desktop".source = lockscreenShell;
    xdg.dataFile."plasma/look-and-feel/sneeuwvlok".source = sessionSplash;

    home.pointerCursor = {
      enable = true;
      package = pkgs.vimix-cursors;
      name = "Vimix-cursors";
      size = 24;
      x11.enable = true;
    };

    # GTK is left to kde-gtk-config's kded module, which writes its config from plasma's (fonts, cursor, icons, and the
    # colour scheme as breeze's colours in colors.css). The one thing it doesn't set is the theme: adw-gtk3, the GTK 3
    # take on libadwaita. Both are pinned to dark, GTK 3 only goes dark through the theme's name and the rest falls back
    # to light whenever the module hasn't written its config (yet)
    dconf.settings."org/gnome/desktop/interface" = {
      gtk-theme = "adw-gtk3-dark";
      color-scheme = "prefer-dark";
    };

    # adw-gtk3 and libadwaita don't use breeze's colours, they take these. The module only adds its import to gtk.css
    # when it's missing. Read when an app starts
    ${namespace}.themes = let
      t = config.${namespace}.themes.token;
      colours = {
        accent_color = "accent";
        accent_bg_color = "accent";
        accent_fg_color = "on-accent";
        destructive_color = "red";
        destructive_bg_color = "red";
        destructive_fg_color = "background";
        success_color = "green";
        success_bg_color = "green";
        success_fg_color = "background";
        warning_color = "yellow";
        warning_bg_color = "yellow";
        warning_fg_color = "background";
        error_color = "red";
        error_bg_color = "red";
        error_fg_color = "background";
        window_bg_color = "background";
        window_fg_color = "foreground";
        view_bg_color = "background";
        view_fg_color = "foreground";
        headerbar_bg_color = "surface";
        headerbar_fg_color = "foreground";
        headerbar_backdrop_color = "background";
        sidebar_bg_color = "surface";
        sidebar_fg_color = "foreground";
        sidebar_backdrop_color = "background";
        secondary_sidebar_bg_color = "surface";
        secondary_sidebar_fg_color = "foreground";
        secondary_sidebar_backdrop_color = "background";
        card_bg_color = "surface";
        card_fg_color = "foreground";
        dialog_bg_color = "surface";
        dialog_fg_color = "foreground";
        popover_bg_color = "surface-high";
        popover_fg_color = "foreground";
        thumbnail_bg_color = "surface";
        thumbnail_fg_color = "foreground";
      };
      named = concatMapStringsSep "\n" (n: "@define-color ${n} ${t colours.${n}};") (builtins.attrNames colours);
    in {
      # the apps' colours (the themes module's targets) follow the wallpaper, one colour scheme each
      schemes = lib.listToAttrs (map (w:
        lib.nameValuePair w.name "${wallpaperThemes}/share/wallpaper-themes/${w.name}/tokens.json") wallpapers);

      targets.gtk3 = {
        path = ".config/gtk-3.0/gtk.css";
        text = ''
          @import 'colors.css';
          ${named}
        '';
      };
      # libadwaita 1.6 moved to css variables, it still reads the named colours for now
      targets.gtk4 = {
        path = ".config/gtk-4.0/gtk.css";
        text = ''
          @import 'colors.css';
          ${named}
          :root {
          ${concatMapStringsSep "\n" (n: "  --${replaceStrings [ "_" ] [ "-" ] n}: ${t colours.${n}};") (builtins.attrNames colours)}
          }
        '';
      };
    };

    systemd.user.services.plasma-wallpaper-rotate = {
      Unit = {
        Description = "Apply today's wallpaper and the colours made from it";
        PartOf = [ "plasma-workspace.target" ];
        After = [ "plasma-plasmashell.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = getExe wallpaperRotate;
        # plasmashell takes a moment before it accepts a wallpaper
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "plasma-workspace.target" ];
    };
    systemd.user.timers.plasma-wallpaper-rotate = {
      Unit.Description = "Rotate the wallpaper daily";
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    systemd.user.services.plasma-panels-follow-screens = {
      Unit = {
        Description = "Give every screen plasma's panel";
        PartOf = [ "plasma-workspace.target" ];
        After = [ "plasma-plasmashell.service" ];
      };
      Service = {
        ExecStart = getExe panelsFollowScreens;
        Restart = "on-failure";
      };
      Install.WantedBy = [ "plasma-workspace.target" ];
    };
    programs.plasma = {
      enable = true;

      immutableByDefault = true;
      windows.allowWindowsToRememberPositions = true;

      inherit panels;
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
        # the colour scheme, icons and wallpaper are the rotation's (plasma-wallpaper-rotate)
        widgetStyle = "Darkly";
        windowDecorations = {
          library = "org.kde.klassy";
          theme = "Klassy";
        };
        cursor = {
          theme = cursor.name;
          size = cursor.size;
        };
      };

      fonts = {
        general = font fonts.sansSerif fonts.sizes.applications;
        fixedWidth = font fonts.monospace fonts.sizes.terminal;
        small = font fonts.sansSerif fonts.sizes.desktop;
        toolbar = font fonts.sansSerif fonts.sizes.desktop;
        menu = font fonts.sansSerif fonts.sizes.desktop;
        windowTitle = font fonts.sansSerif fonts.sizes.desktop;
      };

      # meta+arrows move windows between kzones' zones instead of kwin's gapless half/quarter snapping
      shortcuts.kwin = {
        "Window Quick Tile Left" = "none";
        "Window Quick Tile Right" = "none";
        "Window Quick Tile Top" = "none";
        "Window Quick Tile Bottom" = "none";
        "KZones: Move active window left" = "Meta+Left";
        "KZones: Move active window right" = "Meta+Right";
        "KZones: Move active window up" = "Meta+Up";
        "KZones: Move active window down" = "Meta+Down";
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

        ksplashrc.KSplash = {
          Engine = "KSplashQML";
          Theme = "sneeuwvlok";
        };

        # frameless: no title bars, an outline in the accent colour shows the active window instead
        "klassy/klassyrc" = {
          Windeco = {
            RoundAllCornersWhenNoBorders = true;
            # same as the floating panels (breeze plasma theme)
            WindowCornerRadius = 6;
          };
          WindowOutlineStyle = {
            WindowOutlineThickness = 2;
            WindowOutlineStyleActive = "WindowOutlineAccentColor";
            WindowOutlineStyleInactive = "WindowOutlineContrast";
          };
          "Windeco Exception 0" = {
            Enabled = true;
            ExceptionWindowPropertyType = 0;
            ExceptionWindowPropertyPattern = ".*";
            ExceptionProgramNamePattern = "";
            HideTitleBar = 1;
          };
        };

        kdeglobals = {
          General = {
            # enable font antialiasing
            XftAntialias = true;
            XftHintStyle = "hintslight";
            XftSubPixel = "rgb";

            # used by `preferred://terminal` and "open terminal here", falls back to konsole when unset
            TerminalService = head (toList config.xdg.mimeApps.defaultApplications."x-scheme-handler/terminal");
            # the executable apps with `Terminal=true` in their desktop file (e.g. yazi) run in, also defaults to konsole
            TerminalApplication = config.${namespace}.defaults.terminal;
          };

          # previews of files on the nfs mounts, kde skips remote files (0) by default. In bytes, 100 MiB
          PreviewSettings = {
            MaximumRemoteSize = 104857600;
            EnableRemoteFolderThumbnail = true;
          };
        };

        # the module that writes GTK's config (see above), stylix's kde target left it switched off
        kded5rc."Module-gtkconfig".autoload = true;

        kwalletrc = {
          Wallet.Enabled = true;
        };

        plasmarc = {
          General = {
            RaiseMaximumVolume = true;
            VolumeStep = 2;
          };
        };

        kwinrc = {
          Plugins.kzonesEnabled = true;
          # dragging a window to a screen edge snaps it to kzones' zone there, not kwin's gapless halves and maximize
          Windows = {
            ElectricBorderMaximize = false;
            ElectricBorderTiling = false;
          };
          # several windows can share a zone and stack there, ctrl+alt+up/down cycles through them.
          # every screen keeps its own layout (ctrl+alt+d cycles them), see kzones above
          Script-kzones = {
            layoutsJson = builtins.toJSON kzonesLayouts;
            trackLayoutPerScreen = true;
            enableEdgeSnapping = true;
            enableZoneSelector = false;
          };
        };

        kcminputrc = {
          Keyboard.NumLock.value = 0;
        };
      };
    };
  };
}
