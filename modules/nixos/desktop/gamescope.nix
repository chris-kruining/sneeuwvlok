{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkForce;

  cfg = config.sneeuwvlok.desktop.gamescope;
in {
  options.sneeuwvlok.desktop.gamescope = {
    enable =
      mkEnableOption "Enable Steamdeck ui"
      // {
        default = config.sneeuwvlok.desktop.use == "gamescope";
      };
  };

  config = mkIf cfg.enable {
    sneeuwvlok.desktop.plasma.enable = true;

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
