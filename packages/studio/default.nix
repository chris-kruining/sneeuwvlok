{
  pkgs,
  inputs,
}: let
  inherit (builtins) fetchurl;
  inherit (pkgs) makeDesktopItem copyDesktopItems wineWow64Packages;
  inherit (inputs.erosanix.lib.x86_64-linux) mkWindowsAppNoCC makeDesktopIcon copyDesktopIcons;

  wine = wineWow64Packages.base;
in
  mkWindowsAppNoCC rec {
    inherit wine;

  pname = "studio";
  version = "2.25.12";

    src = fetchurl {
      url = "https://studio.download.bricklink.info/Studio2.0+EarlyAccess/Archive/2.25.12_1/Studio+2.0+EarlyAccess.exe";
      sha256 = "sha256:1xl3zvzkzr64zphk7rnpfx3whhbaykzw06m3nd5dc12r2p4sdh3v";
    };

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

    winAppInstall = ''
      wine64 ${src}

      wineserver -W
      wine64 reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /t REG_SZ /v UseTakeFocus /d N /f
    '';

    winAppPreRun = ''
      wineserver -W
      wine64 reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /t REG_SZ /v UseTakeFocus /d N /f
    '';

    winAppRun = ''
      wine64 "$WINEPREFIX/drive_c/Program Files/Studio 2.0/Studio.exe" "$ARGS"
    '';

    winAppPostRun = "";
    installPhase = ''
      runHook preInstall

      ln -s $out/bin/.launcher $out/bin/${pname}

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
