{ lib, config, namespace, inputs, ... }:let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.desktop.gamescope;
in
{
  imports = [ inputs.jovian.nixosModules.default ];

  options.${namespace}.desktop.gamescope = {
    enable = mkEnableOption "Enable Steamdeck ui";
  };

  config = mkIf cfg.enable {
    "${namespace}".desktop.kde.enable = true;

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
