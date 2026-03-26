{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.onlyoffice;
in {
  options.sneeuwvlok.application.onlyoffice = {
    enable = mkEnableOption "enable onlyoffice";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [onlyoffice-desktopeditors];
  };
}
