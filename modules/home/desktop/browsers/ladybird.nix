{ config, lib, pkgs, user, ... }:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  cfg = config.modules.${user}.desktop.browsers.ladybird;
in {
  options.modules.${user}.desktop.browsers.ladybird = {
    enable = mkEnableOption "Enable Ladybird";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      ladybird
    ];
  };
}
