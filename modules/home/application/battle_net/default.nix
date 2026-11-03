{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.battle_net;
in
{
  options.${namespace}.application.battle_net = {
    enable = mkEnableOption "enable Battle.net launcher";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs.${namespace}; [ battle_net ];
  };
}
