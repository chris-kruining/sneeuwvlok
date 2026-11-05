{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption mkDefault;

  cfg = config.${namespace}.desktop.plasma;
  splash = config.${namespace}.boot.splash;

  anurati = "${pkgs.${namespace}.anurati}/share/fonts/opentype/Anurati-Regular.otf";
  cursor = { package = pkgs.vimix-cursors; name = "Vimix-cursors"; size = 24; };

  # breeze's login screen made to look like the lock screen: its clock and halo, no avatar or buttons. The wallpaper is
  # the splash's, the one of the day
  sddmTheme = pkgs.runCommand "sddm-theme-sneeuwvlok" { } ''
    dir=$out/share/sddm/themes/sneeuwvlok
    mkdir -p $(dirname $dir)
    cp -r ${pkgs.kdePackages.plasma-desktop}/share/sddm/themes/breeze $dir
    chmod -R u+w $dir
    cd $dir
    patch -p1 < ${./sddm/theme.patch}
    substitute ${../../../home/desktop/plasma/lockscreen/AestheticClock.qml} AestheticClock.qml \
      --subst-var-by anurati ${anurati} \
      --subst-var-by poppins ${pkgs.poppins}/share/fonts/truetype/Poppins-Light.ttf
    ${lib.optionalString splash.enable ''
      cat > theme.conf.user <<EOF
      [General]
      background=${splash.wallpaper}
      color=#000000
      EOF
    ''}
  '';
in
{
  options.${namespace}.desktop.plasma = {
    enable = mkEnableOption "Enable KDE Plasma" // {
      default = (config.${namespace}.desktop.use == "plasma");
    };
  };

  config = mkIf cfg.enable {
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      elisa
      kmahjongg
      kmines
      konversation
      kpat
      ksudoku
      konsole
      kate
      ghostwriter
      # oxygen
    ];
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    # the login screen's cursor, the session's own comes from stylix
    environment.systemPackages = [ cursor.package ];

    services = {
      xserver.enable = false;

      desktopManager.plasma6.enable = true;

      displayManager = {
        # a default, gamescope turns plasma on too and hands its session to jovian
        defaultSession = mkDefault "plasma";
        sddm = {
          enable = true;
          wayland.enable = true;
          theme = "${sddmTheme}/share/sddm/themes/sneeuwvlok";
          settings.Theme = {
            CursorTheme = cursor.name;
            CursorSize = cursor.size;
          };
        };
      };
    };

    # the greeter takes its colours from its own kdeglobals, the wallpaper rotation puts the day's scheme next to the
    # splash's wallpaper
    systemd.tmpfiles.rules = mkIf splash.enable [
      "d /var/lib/sddm/.config 0755 sddm sddm -"
      "L+ /var/lib/sddm/.config/kdeglobals - - - - ${dirOf splash.wallpaper}/kdeglobals"
    ];
  };
}
