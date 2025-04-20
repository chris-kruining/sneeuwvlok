{ pkgs, lib, inputs }: let
  inherit (builtins) fetchurl;
  inherit (pkgs) makeDesktopItem wineWowPackages;
  inherit (inputs.erosanix.lib.x86_64-linux) mkWindowsApp makeDesktopIcon;

  wine = wineWowPackages.base;
in mkWindowsApp rec {
  inherit wine;

  pname = "studio";
  version = "2.25.4_1";

  src = fetchurl {
    url = "https://studio.download.bricklink.info/Studio2.0+EarlyAccess/Archive/2.25.4_1/Studio+2.0+EarlyAccess.exe";
    sha256 = "sha256:1gw6pyvfr7zr42g21hqgiwkjs88nvhq2c2v40y21frvwv17hja92";
  };

  enableMonoBootPrompt = false;
  dontUnpack = true;

  wineArch = "win64";
  enableInstallNotification = true;

  fileMap = {
    "$HOME/.cache/${pname}" = "drive_c/${pname}/${pname}-cache";
  };

  fileMapDuringAppInstall = false;

  persistRegistry = false;
  persistRuntimeLayer = false;
  inputHashMethod = "store-path";

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

  enabledWineSymlinks = { };
  graphicsDriver = "auto";
  inhibitIdle = false;

  winAppInstall = ''
    d="$WINEPREFIX/drive_c/${pname}"
    config_dir="$HOME/.config/studio"

    mkdir -p "$d"
    wine ${src}

    mkdir -p "$config_dir"
  '';

  winAppPreRun = '''';

  winAppRun = ''
    wine "$WINEPREFIX/drive_c/${pname}/studio-${version}-64.exe" "$ARGS"
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

  meta = with lib; {
    description = "App for creating lego builds";
    homepage = "https://www.bricklink.com/v3/studio/main.page";
    license = "";
    maintainers = [];
    platforms = [ "x86_64-linux" ];
  };
}
