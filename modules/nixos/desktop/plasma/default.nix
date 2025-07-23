{ pkgs, lib, config, namespace, ... }:let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.desktop.plasma;
in
{
  options.${namespace}.desktop.plasma = {
    enable = mkEnableOption "Enable KDE Plasma";
  };

  config = mkIf cfg.enable {
    environment.plasma6.excludePackages = with pkgs.kdePackages; [ konsole kate ghostwriter oxygen ];
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
