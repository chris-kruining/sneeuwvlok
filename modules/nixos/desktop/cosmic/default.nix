{
  lib,
  config,
  namespace,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkForce;

  cfg = config.${namespace}.desktop.cosmic;
in {
  options.${namespace}.desktop.cosmic = {
    enable =
      mkEnableOption "Enable Cosmic desktop"
      // {
        default = config.${namespace}.desktop.use == "cosmic";
      };
  };

  config = mkIf cfg.enable {
    services = {
      displayManager = {
        cosmic-greeter.enable = true;
        autoLogin = {
          enable = true;
          user = "chris";
        };
      };
      desktopManager.cosmic.enable = true;
    };
  };
}
