{
  lib,
  config,
  namespace,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.desktop.cosmic;
in {
  options.sneeuwvlok.desktop.cosmic = {
    enable =
      mkEnableOption "Enable Cosmic desktop"
      // {
        default = config.sneeuwvlok.desktop.use == "cosmic";
      };
  };

  config = mkIf cfg.enable {
    services = {
      displayManager.cosmic-greeter.enable = true;
      desktopManager.cosmic.enable = true;
    };
  };
}
