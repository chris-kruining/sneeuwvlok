{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.services.games.minecraft = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Minecraft";
  };

  config = mkIf config.modules.services.games.minecraft.enable {
    services.minecraft-servers = {
      enable = true;
      eula = true;

      dataDir = "/var/lib/minecraft";

      servers = {
        vanilla = {
          enable = true;
          autoStart = true;

          package = pkgs.fabricServers.fabric-1_18_2.override { loaderVersion = "0.14.9"; };

          serverProperties = {
            gamemode = "survival";
            difficulty = 3;
            motd = "Chris' vanilla server";
            white-list = true;
            simulation-distance = 10;
            server-port = 25501;
          };

          whitelist = {
            ChrisPBacon = "e6128495-075b-44a9-87f6-8d844d5ea0e4";
          };

          jvmOpts = "-Xms4092M -Xmx4092M -XX:+UseG1GC";

          symlinks = let
            inherit (lib.attrsets) attrValues;
            inherit (pkgs) linkFarmFromDrvs fetchurl;
          in{
            mods = linkFarmFromDrvs "mods" (attrValues {
              Terraforged = fetchurl { url = "https://cdn.modrinth.com/data/FIlZB9L0/versions/EVe9wYaj/Terra-fabric-6.4.3-BETA%2Bab60f14ff.jar"; sha512 = "90dc1215b352fcbce0219dab616dc2be28eaff4622233cbfadd6060aa52432f2ba86f05f1118314b46102b3ab3c6f8070e6780cf6512a8961ac47c235dd764f9"; };
              DistantHorizons = fetchurl { url = "https://cdn.modrinth.com/data/uCdwusMi/versions/jptcCdp2/DistantHorizons-2.2.1-a-1.20.4-forge-fabric.jar"; sha512 = "47368d91099d0b5f364339a69f4e425f8fb1e3a7c3250a8b649da76135e68a22f1a76b191c87e15a5cdc0a1d36bc57f2fa825490d96711d09d96807be97d575d"; };
            });
          };
        };
      };
    };
  };
}
