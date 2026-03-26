{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.desktop.plasma;
in {
  options.sneeuwvlok.desktop.plasma = {
    enable =
      mkEnableOption "Enable KDE Plasma"
      // {
        default = config.sneeuwvlok.desktop.use == "plasma";
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

    services = {
      xserver.enable = false;

      desktopManager.plasma6.enable = true;

      displayManager = {
        defaultSession = "plasma";
        sddm = {
          enable = true;
          wayland.enable = true;
        };
      };
    };
  };
}
