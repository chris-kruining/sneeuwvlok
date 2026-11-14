{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.game.ut2004;
in
{
  options.${namespace}.game.ut2004 = {
    enable = mkEnableOption "Unreal Tournament 2004, on OldUnreal's patch with the game data they distribute";
  };

  # Unlike ut1999 it binds to every address by itself, `-multihome` would bind it to one and it then misses the LAN
  # browsers' broadcasts
  config = mkIf cfg.enable {
    home.packages = [ pkgs.ut2004 ];
  };
}
