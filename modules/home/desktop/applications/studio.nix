{ pkgs, config, lib, user, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.modules.${user}.desktop.applications.studio;
in
{
  options.modules.${user}.desktop.applications.studio = {
    enable = mkEnableOption "Enable Bricklink Studio";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wineWowPackages.full
      my.studio
    ];
  };
}
