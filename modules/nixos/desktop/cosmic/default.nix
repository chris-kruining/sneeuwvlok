{
  lib,
  config,
  namespace,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

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
      displayManager.cosmic-greeter.enable = true;
      desktopManager.cosmic.enable = true;
    };
  };
}
