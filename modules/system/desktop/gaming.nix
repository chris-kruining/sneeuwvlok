{ inputs, lib, config, ... }: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.desktop.gaming;
in
{
  imports = [ inputs.jovian.nixosModules.default ];

  options.modules.desktop.gaming = {
    enable = mkEnableOption "enable steamdeck like desktop";
  };

  config = mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;

    jovian = {
      # devices = {
      #   steamdeck = {
      #     enable = true;
      #     enableGyroDsuService = true;
      #     autoUpdate = true;
      #   };
      # };
      steam = {
        enable = true;
        autoStart = true;
        user = "chris";
        updater.splash = "steamos";
        # desktopSession = "plasma";
      };
      steamos.useSteamOSConfig = true;
    };
  };
}
