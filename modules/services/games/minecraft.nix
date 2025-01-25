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

      user = "chris";
      dataDir = "/var/lib/minecraft";

      servers = {
        vanilla = {
          enable = true;
          autoStart = true;

          package = pkgs.fabricServers.fabric-1_20_4.override { loaderVersion = "0.15.11"; };

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
              FabricApi = fetchurl { url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/QVBohPm2/fabric-api-0.97.2%2B1.20.4.jar"; sha512 = "8f02bf562781a2f08294736eff784b7e7463be1595b1e3b4f53d4dcb57fc0643890078265141c3bce882dfec6e77553d2db252992fdfbd55cd7d32777adb9d78"; };
              Terralith = fetchurl { url = "https://cdn.modrinth.com/data/8oi3bsk5/versions/WeYhEb5d/Terralith_1.20.x_v2.5.4.jar"; sha512 = "885e171d8b34aae7e142f082d0364285ec5a8e8342f11c60d341f7a94083d5a42c4e30612fe4f9f64d57b484396a3dff3a224e2a2497d4ced8d22f2ad6cd561d"; };
              DistantHorizons = fetchurl { url = "https://cdn.modrinth.com/data/uCdwusMi/versions/jptcCdp2/DistantHorizons-2.2.1-a-1.20.4-forge-fabric.jar"; sha512 = "47368d91099d0b5f364339a69f4e425f8fb1e3a7c3250a8b649da76135e68a22f1a76b191c87e15a5cdc0a1d36bc57f2fa825490d96711d09d96807be97d575d"; };
            });
          };
        };
      };
    };
  };
}
