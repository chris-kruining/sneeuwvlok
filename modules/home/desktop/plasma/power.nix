{ config, lib, namespace, osConfig ? {}, ... }:
let
  cfg = config.${namespace}.desktop.plasma;
  osCfg = osConfig.${namespace}.desktop.plasma or { enable = false; };
in
{
  options.${namespace}.desktop.plasma = {

  };

  config = mkIf osCfg.enable {
    programs.plasma.powerdevil = {
      AC = {
        powerButtonAction = "shutDown";
        whenLaptopLidClosed = "doNothing";

        autoSuspend.action = "nothing";
        dimDisplay.enable = false;

        turnOffDisplay = {
          idleTimeout = "never";
        };
      };

      battery = {
        powerButtonAction = "shutDown";
        whenLaptopLidClosed = "doNothing";

        autoSuspend.action = "nothing";
        dimDisplay.enable = false;

        turnOffDisplay = {
          idleTimeout = "never";
        };
      };

      lowBattery = {
        powerButtonAction = "shutDown";
        whenLaptopLidClosed = "doNothing";

        autoSuspend.action = "nothing";
        dimDisplay.enable = false;

        turnOffDisplay = {
          idleTimeout = "never";
        };
      };
    };
  };
}