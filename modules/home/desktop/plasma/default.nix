{ config, lib, pkgs, inputs, namespace, osConfig ? {}, ... }:
let
  inherit (lib) mkIf mkOption genAttrs optional types head toList getExe concatMapStringsSep replaceStrings;

  cfg = config.${namespace}.desktop.plasma;
  osCfg = osConfig.${namespace}.desktop.plasma or { enable = false; };
  app = config.${namespace}.application;

  pmDir = "${config.xdg.dataHome}/plasma-manager";

  wallpapers = import ./wallpapers.nix { inherit (pkgs) fetchurl; };

  # meta only opens a launcher that lives in a panel, this transparent button keeps it invisible there
  launcherButton = pkgs.writeText "launcher-button.svg" ''<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1" viewBox="0 0 1 1"/>'';

  panels = import ./panels.nix { inherit (cfg) launchers; inherit launcherButton; };
  panelHeights = lib.listToAttrs (map (p: lib.nameValuePair p.location p.height) panels);

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
    text = replaceStrings [ "@themes@" "@changeicons@" "@splashes@" "@splash@" ] [
      "${wallpaperThemes}"
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

  fonts = config.stylix.fonts;
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
    # kde-gtk-config's kded module (part of plasma6's required packages, so it can't be excluded) rewrites the GTK
    # config as plain files whenever the look-and-feel is applied, which stylix does on every activation. It's loaded
    # on demand, so `autoload=false` doesn't stop it. Overwriting instead of backing up keeps activations from failing
    # on the backup of the previous rewrite
    gtk.gtk2.force = true;

    home.packages = with pkgs; [
      darkly klassy wallpaperThemes wallpaperRotate
      inputs.appgrid.packages.${stdenv.hostPlatform.system}.default
    ];

    xdg.dataFile."plasma/shells/org.kde.plasma.desktop".source = lockscreenShell;
    xdg.dataFile."plasma/look-and-feel/sneeuwvlok".source = sessionSplash;

    # plasma does qt itself; stylix's qt target forces the breeze style over the chosen one (QT_STYLE_OVERRIDE), and
    # its kde target pins its own colour scheme and wallpaper on every activation, which would undo the rotation
    stylix.targets.qt.enable = false;
    stylix.targets.kde.enable = false;
    stylix.cursor = {
      package = pkgs.vimix-cursors;
      name = "Vimix-cursors";
      size = 24;
    };

    # kwin keeps a tiling layout per desktop and screen, keyed by their uuids, and its padding wins over the global one.
    # windows are shift-dragged (or meta+arrowed) into these zones, several windows can share a zone and stack there.
    # the laptop panel gets one full zone, external screens two halves. kwin only reads this at login.
    # the zones are floating (exact) ones so windows line up with the floating panels: 8px from the screen sides like
    # the panels, 10px between windows and to the panels. plasma de-floats a panel once a window gets within its
    # 8px float margin (+1), which the 10px keeps clear of.
    home.activation.kwinTiling = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      rc="${config.xdg.configHome}/kwinrc"
      outputs="${config.xdg.configHome}/kwinoutputconfig.json"
      if [ -f "$rc" ]; then
        ${pkgs.gnused}/bin/sed -n 's/^\[Tiling\]\[\([^]]*\)\]\[\([^]]*\)\]$/\1 \2/p' "$rc" | while read -r desktop screen; do
          tiles=$(${getExe pkgs.jq} -c -r --arg uuid "$screen" \
            --argjson top ${toString panelHeights.top} --argjson bottom ${toString panelHeights.bottom} \
            --argjson margin 8 --argjson gap 10 '
              .[] | select(.name == "outputs") | .data[] | select(.uuid == $uuid)
              | (.mode.width / .scale) as $w | (.mode.height / .scale) as $h
              | ($h - $top - $bottom) as $ah
              | (if (.connectorName | startswith("eDP")) then [[$margin, $w - $margin]]
                 else [[$margin, ($w - $gap) / 2], [($w + $gap) / 2, $w - $margin]] end)
              | { layoutDirection: "floating", tiles: map({
                  x: (.[0] / $w), width: ((.[1] - .[0]) / $w),
                  y: (($margin + $gap) / $ah), height: (($ah - 2 * ($margin + $gap)) / $ah)
                }) }
              | tojson' "$outputs" 2>/dev/null || true)
          [ -n "$tiles" ] || continue
          run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$rc" \
            --group Tiling --group "$desktop" --group "$screen" --key padding ${toString config.programs.plasma.kwin.tiling.padding}
          run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$rc" \
            --group Tiling --group "$desktop" --group "$screen" --key tiles "$tiles"
        done
      fi
    '';

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
    xdg.configFile = mkIf config.gtk.enable (
      genAttrs ["gtk-3.0/settings.ini" "gtk-3.0/gtk.css" "gtk-4.0/settings.ini" "gtk-4.0/gtk.css"] (_: {force = true;})
    );

    programs.plasma = {
      enable = true;

      immutableByDefault = true;
      windows.allowWindowsToRememberPositions = true;

      inherit panels;
      powerdevil = import ./power.nix;

      kwin = {
        edgeBarrier = 0;
        cornerBarrier = false;
        # the gaps are built into the zones themselves, see the kwinTiling activation
        tiling.padding = 0;
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
          theme = config.stylix.cursor.name;
          size = config.stylix.cursor.size;
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

      # meta+arrows move windows between the custom zones (which have gaps) instead of the gapless half/quarter snapping
      shortcuts.kwin = {
        "Window Quick Tile Left" = "none";
        "Window Quick Tile Right" = "none";
        "Window Quick Tile Top" = "none";
        "Window Quick Tile Bottom" = "none";
        "Window Custom Quick Tile Left" = "Meta+Left";
        "Window Custom Quick Tile Right" = "Meta+Right";
        "Window Custom Quick Tile Top" = "Meta+Up";
        "Window Custom Quick Tile Bottom" = "Meta+Down";
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
