{ lib, config, namespace, inputs, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.desktop.gamescope;
in
{
  imports = [ inputs.jovian.nixosModules.default ];

  options.${namespace}.desktop.gamescope = {
    enable = mkEnableOption "Enable Steamdeck ui" // {
      default = (config.${namespace}.desktop.use == "gamescope");
    };
  };

  config = mkIf cfg.enable {
    ${namespace}.desktop.plasma.enable = true;

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
