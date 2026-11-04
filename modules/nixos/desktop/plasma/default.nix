{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption mkDefault;

  cfg = config.${namespace}.desktop.plasma;
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

    services = {
      xserver.enable = false;

      desktopManager.plasma6.enable = true;

      displayManager = {
        # a default, gamescope turns plasma on too and hands its session to jovian
        defaultSession = mkDefault "plasma";
        sddm = {
          enable = true;
          wayland.enable = true;
        };
      };
    };
  };
}
