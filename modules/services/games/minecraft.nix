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
    services = {
      minecraft-servers = {
        enable = true;
        eula = true;
        openFirewall = true;

        user = "chris";
        dataDir = "/var/lib/minecraft";

        managementSystem.systemd-socket.enable = true;

        servers = {
          vanilla = {
            enable = true;
            autoStart = true;

            package = pkgs.fabricServers.fabric-1_21_4.override { loaderVersion = "0.16.10"; };

            serverProperties = {
              gamemode = "survival";
              difficulty = 3;
              motd = "Chris' vanilla server";
              white-list = true;
              simulation-distance = 10;
              server-port = 25501;
              level-name = "world";

              allow-flight = true;
              enable-command-block = true;
              enforce-whitelist = true;
              spawn-protection = 0;
            };

            whitelist = {
              ChrisPBacon = "e6128495-075b-44a9-87f6-8d844d5ea0e4";
              satanjr616 = "1718f9d5-df1d-4aac-b10c-3229a0f1e8b2";
              Ono95 = "010e7652-6d5d-4f9e-af89-438c8fe694ca";
              JackLeLumber = "41910a94-8c8e-4528-a8ca-a2d7043f069d";
              DarkyLink = "6faddb7f-12a9-4aac-bc08-dd6db892a380";
              Archonite86 = "b5ab594d-de1c-4453-ba32-9107452be51b";
              NotACultist86 = "44ac3f7c-0e18-4234-bb04-11a0652cdaeb";
            };

            jvmOpts = "-Xms4092M -Xmx4092M -XX:+UseG1GC -Djava.net.preferIPv4Stack=true";

            symlinks = let
              inherit (lib.attrsets) attrValues;
              inherit (pkgs) linkFarmFromDrvs fetchurl;
            in {
              mods = linkFarmFromDrvs "mods" (attrValues {
                FabricApi = fetchurl { url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/ZNwYCTsk/fabric-api-0.118.0%2B1.21.4.jar"; sha512 = "1e0d31b6663dc2c7be648f3a5a9cf7b698b9a0fd0f7ae16d1d3f32d943d7c5205ff63a4f81b0c4e94a8997482cce026b7ca486e99d9ce35ac069aeb29b02a30d"; };
                Terralith = fetchurl { url = "https://cdn.modrinth.com/data/8oi3bsk5/versions/MuJMtPGQ/Terralith_1.21.x_v2.5.8.jar"; sha512 = "f862ed5435ce4c11a97d2ea5c40eee9f817c908f3223b5fd3e3fff0562a55111d7429dc73a2f1ca0b1af7b1ff6fa0470ed6efebb5de13336c40bb70fb357dd60"; };
                # DistantHorizons = fetchurl { url = "https://cdn.modrinth.com/data/uCdwusMi/versions/jptcCdp2/DistantHorizons-2.2.1-a-1.20.4-forge-fabric.jar"; sha512 = "47368d91099d0b5f364339a69f4e425f8fb1e3a7c3250a8b649da76135e68a22f1a76b191c87e15a5cdc0a1d36bc57f2fa825490d96711d09d96807be97d575d"; };
              });
            };

            files."ops.json" = {
              value = [
                {
                  uuid = "e6128495-075b-44a9-87f6-8d844d5ea0e4";
                  name = "ChrisPBacon";
                  level = 4;
                  bypassesPlayerLimit = false;
                }
                {
                  uuid = "6faddb7f-12a9-4aac-bc08-dd6db892a380";
                  name = "DarkyLink";
                  level = 4;
                  bypassesPlayerLimit = false;
                }
              ];
            };
          };
        };
      };
    };
  };
}
