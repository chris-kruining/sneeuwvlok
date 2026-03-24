{ lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption mkForce;

  cfg = config.${namespace}.desktop.gamescope;
in
{
  options.${namespace}.desktop.gamescope = {
    enable = mkEnableOption "Enable Steamdeck ui" // {
      default = (config.${namespace}.desktop.use == "gamescope");
    };
  };

  config = mkIf cfg.enable {
    ${namespace}.desktop.plasma.enable = true;

    services.displayManager.sddm.enable = mkForce false;
    services.displayManager.gdm.enable = mkForce false;

    jovian = {
      steam = {
        enable = true;
        autoStart = true;
        user = "chris";
        updater.splash = "steamos";
        desktopSession = "plasma";
      };
      steamos.useSteamOSConfig = true;
    };
  };
}
