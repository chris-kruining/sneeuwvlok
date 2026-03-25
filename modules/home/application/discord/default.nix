{
  inputs,
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.discord;
in {
  options.sneeuwvlok.application.discord = {
    enable = mkEnableOption "enable discord (vesktop)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [vesktop];
  };
}
