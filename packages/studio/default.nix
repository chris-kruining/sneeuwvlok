{
  pkgs,
  inputs,
}: let
  inherit (builtins) hashString substring;
  inherit (pkgs) makeDesktopItem copyDesktopItems wineWow64Packages runCommandLocal writeShellScriptBin;
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
    buildInputs = [fusermount];

    winAppInstall = ''
      wine ${src}

      wineserver -w
      wine reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /t REG_SZ /v UseTakeFocus /d N /f
    '';

    winAppPreRun = ''
      wineserver -w
      wine reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /t REG_SZ /v UseTakeFocus /d N /f
    '';

    winAppRun = ''
      wine "$WINEPREFIX/drive_c/Program Files/Studio 2.0 EarlyAccess/Studio.exe" "$ARGS"
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
