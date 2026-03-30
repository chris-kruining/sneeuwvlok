{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.teamspeak;
in {
  options.sneeuwvlok.application.teamspeak = {
    enable = mkEnableOption "enable teamspeak";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # teamspeak3
      teamspeak6-client
    ];
  };
}
