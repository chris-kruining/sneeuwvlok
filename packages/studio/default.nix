{
  pkgs,
  inputs,
}: let
  inherit (builtins) hashString substring;
  inherit (pkgs) makeDesktopItem copyDesktopItems wineWow64Packages runCommandLocal writeShellScriptBin gnugrep;
  inherit (inputs.erosanix.lib.x86_64-linux) mkWindowsAppNoCC makeDesktopIcon copyDesktopIcons;

  wine = wineWow64Packages.base;

  # mkWindowsApp unmounts its unionfs bottle with `fusermount`, which NixOS no longer has (only fusermount3). When
  # that fails, its `rm -fR` of the bottle goes through the still mounted union and wipes the runtime layer
  fusermount = writeShellScriptBin "fusermount" ''exec /run/wrappers/bin/fusermount3 "$@"'';
in
  mkWindowsAppNoCC rec {
    inherit wine;

  pname = "studio";
  # The installer comes from the `studio` flake input, which only knows its hash. A new hash means a new version,
  # which makes mkWindowsApp reinstall it
  version = "early-access-${substring 0 8 (hashString "sha256" inputs.studio.narHash)}";

    # The input is stored as a file called `source`, wine wants an .exe
    src = runCommandLocal "Studio+2.0+EarlyAccess.exe" {} "ln -s ${inputs.studio} $out";

    enableMonoBootPrompt = false;
    dontUnpack = true;

    wineArch = "win64";
    enableInstallNotification = true;

    fileMap = {
      "$HOME/.config/${pname}/Stud.io" = "drive_c/users/$USER/AppData/Local/Stud.io";
      "$HOME/.config/${pname}/Bricklink" = "drive_c/users/$USER/AppData/LocalLow/Bricklink";
    };

    fileMapDuringAppInstall = false;

    persistRegistry = false;
    persistRuntimeLayer = true;
    inputHashMethod = "version";

    # Can be used to precisely select the Direct3D implementation.
    #
    # | enableVulkan | rendererOverride | Direct3D implementation |
    # |--------------|------------------|-------------------------|
    # | false        | null             | OpenGL                  |
    # | true         | null             | Vulkan (DXVK)           |
    # | *            | dxvk-vulkan      | Vulkan (DXVK)           |
    # | *            | wine-opengl      | OpenGL                  |
    # | *            | wine-vulkan      | Vulkan (VKD3D)          |
    enableVulkan = false;
    rendererOverride = null;

    enableHUD = false;

    enabledWineSymlinks = {};
    graphicsDriver = "auto";
    inhibitIdle = false;

    nativeBuildInputs = [copyDesktopIcons copyDesktopItems];
    buildInputs = [fusermount gnugrep];

    winAppInstall = ''
      wine ${src}

      wineserver -w
      wine reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /t REG_SZ /v UseTakeFocus /d N /f
    '';

    winAppPreRun = ''
      wineserver -w
      wine reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /t REG_SZ /v UseTakeFocus /d N /f
    '';

    # Studio's exit can crash halfway, which leaves Studio.exe a zombie whose other threads stay blocked in wine; the
    # launcher then waits forever and the next start says another instance is running. So instead of waiting on wine,
    # wait while a live Studio.exe or Patcher.exe runs in this prefix (Studio quits for the patcher, which starts it
    # again after an update), then stop the prefix ourselves
    winAppRun = ''
      alive () {
        [ -e /proc/$1 ] && [ "$(sed 's/.*) //' /proc/$1/stat | cut -d ' ' -f 1)" != Z ]
      }

      studio_running () {
        local process
        for process in /proc/[0-9]*
        do
          case "$(cat $process/comm)" in
            Studio.exe|Patcher.exe) ;;
            *) continue ;;
          esac
          alive ''${process#/proc/} && tr '\0' '\n' < $process/environ | grep -qxF "WINEPREFIX=$WINEPREFIX" && return 0
        done 2>/dev/null
        return 1
      }

      wine "$WINEPREFIX/drive_c/Program Files/Studio 2.0 EarlyAccess/Studio.exe" "$ARGS" &
      studio=$!

      while alive $studio || studio_running
      do
        sleep 1
      done

      wineserver -k
      wait $studio
    '';

    winAppPostRun = "";
    installPhase = ''
      runHook preInstall

      mv $out/bin/.launcher $out/bin/${pname}

      runHook postInstall
    '';

    desktopItems = [
      (makeDesktopItem {
        mimeTypes = [];

        name = pname;
        exec = pname;
        icon = pname;
        desktopName = "Bricklink studio";
        genericName = "Lego creation app";
        categories = [];
      })
    ];

    desktopIcon = makeDesktopIcon {
      name = pname;
      src = ./studio.png;
    };

    meta = {
      description = "App for creating lego builds";
      homepage = "https://www.bricklink.com/v3/studio/main.page";
      license = "";
      maintainers = [];
      platforms = ["x86_64-linux"];
    };
  }
