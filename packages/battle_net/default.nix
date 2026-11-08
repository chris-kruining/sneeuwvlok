{
  pkgs,
  inputs,
}: let
  inherit (builtins) fetchurl;
  inherit (pkgs) makeDesktopItem copyDesktopItems wineWow64Packages writeShellScriptBin;
  inherit (inputs.erosanix.lib.x86_64-linux) mkWindowsAppNoCC makeDesktopIcon copyDesktopIcons;

  wine = wineWow64Packages.base;

  # mkWindowsApp unmounts its unionfs bottle with `fusermount`, which NixOS no longer has (only fusermount3). When
  # that fails, its `rm -fR` of the bottle goes through the still mounted union and wipes the runtime layer
  fusermount = writeShellScriptBin "fusermount" ''exec /run/wrappers/bin/fusermount3 "$@"'';
in
  mkWindowsAppNoCC rec {
    inherit wine;

  pname = "battle_net";
  version = "1.0.0";

    src = fetchurl {
      url = "https://download.battle.net/?product=bnetdesk";
      sha256 = "sha256:1jyn148phq8qd36x34w3kdywhbn1r83b3v518bbx9ilrgl9mn5xb";
    };

    enableMonoBootPrompt = false;
    dontUnpack = true;

    wineArch = "win64";
    enableInstallNotification = true;

    fileMap = {
      "$HOME/.config/${pname}/Battle.net" = "drive_c/users/$USER/AppData/Local/Battle.net";
      # "$HOME/.config/${pname}/Stud.io" = "drive_c/users/$USER/AppData/Roaming/Battle.net";
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

      wineserver -W
      wine reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /t REG_SZ /v UseTakeFocus /d N /f
    '';

    winAppPreRun = ''
      wineserver -W
      wine reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /t REG_SZ /v UseTakeFocus /d N /f
    '';

    winAppRun = ''
      wine "$WINEPREFIX/drive_c/Program Files/Battle.net/Battle.net.exe" "$ARGS"
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
        desktopName = "Battle.net";
        genericName = "Crap kut launcher want klote blizzard weigert te integreren met steam";
        categories = [];
      })
    ];

    desktopIcon = makeDesktopIcon {
      name = pname;
      src = ./battle.net.png;
    };

    meta = {
      description = "Crap kut launcher want klote blizzard weigert te integreren met steam";
      homepage = "https://download.battle.net/en-us/desktop";
      license = "";
      maintainers = [];
      platforms = ["x86_64-linux"];
    };
  }
