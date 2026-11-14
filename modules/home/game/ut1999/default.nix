{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption getExe;

  cfg = config.${namespace}.game.ut1999;

  # The game takes the address its hostname resolves to as its own, which NixOS makes 127.0.0.2. Bound there, its LAN
  # broadcasts never leave the machine, so it's given the address it reaches the network with instead
  launcher = pkgs.writeShellScript "ut1999" ''
    address=$(${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 2>/dev/null | ${pkgs.gnused}/bin/sed -n 's/.* src \([0-9.]*\).*/\1/p')
    exec ${getExe pkgs.ut1999} ''${address:+"-multihome=$address"} "$@"
  '';

  game = pkgs.symlinkJoin {
    name = "ut1999-lan";
    paths = [ pkgs.ut1999 ];
    postBuild = ''
      rm $out/bin/ut1999
      ln -s ${launcher} $out/bin/ut1999
    '';
    inherit (pkgs.ut1999) meta;
  };
in
{
  options.${namespace}.game.ut1999 = {
    enable = mkEnableOption "Unreal Tournament (GOTY), on OldUnreal's patch with the game data they distribute";
  };

  config = mkIf cfg.enable {
    home.packages = [ game ];
  };
}
