{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.services.games.palworld = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Palworld";
  };

  config = mkIf config.modules.services.games.palworld.enable {
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
