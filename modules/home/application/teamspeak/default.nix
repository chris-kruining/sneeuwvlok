{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.teamspeak;
in
{
  options.${namespace}.application.teamspeak = {
    enable = mkEnableOption "enable teamspeak";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ teamspeak_client ];
  };
}
