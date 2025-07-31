{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.games.palworld;
in
{
  options.${namespace}.services.games.palworld = {
    enable = mkEnableOption "Palworld";
  };

  config = mkIf cfg.enable {
#     kaas = (pkgs.mkSteamServer rec {
#       name = "Palworld";
#       src = pkgs.fetchSteam {
#         inherit name;
#         appId = "2394010";
#         hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
#       };
#
#       sartCmd = "PalServer.sh";
#       hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
#     });
  };
}
