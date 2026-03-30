{
  config,
  lib,
  self,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.studio;
in {
  options.sneeuwvlok.application.studio = {
    enable = mkEnableOption "enable Bricklink Studio";
  };

  config = mkIf cfg.enable {
    home.packages = [self.packages.studio];
  };
}
