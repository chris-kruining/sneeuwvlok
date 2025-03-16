{ config, options, lib, pkgs, inputs, ... }:
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

        managementSystem = {
          tmux.enable = false;
          systemd-socket.enable = true;
        };

        servers = let
          whitelist = {
            ChrisPBacon = "e6128495-075b-44a9-87f6-8d844d5ea0e4";
            satanjr616 = "1718f9d5-df1d-4aac-b10c-3229a0f1e8b2";
            Ono95 = "010e7652-6d5d-4f9e-af89-438c8fe694ca";
            JackLeLumber = "41910a94-8c8e-4528-a8ca-a2d7043f069d";
            DarkyLink = "6faddb7f-12a9-4aac-bc08-dd6db892a380";
            Archonite86 = "b5ab594d-de1c-4453-ba32-9107452be51b";
            NotACultist86 = "44ac3f7c-0e18-4234-bb04-11a0652cdaeb";
          };
          ops = [
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
          jvmOpts = "-Xms2048M -Xmx2048M -XX:+UseG1GC";
        in {
          vanilla = {
            enable = true;
            autoStart = true;
            restart = "always";
            inherit whitelist;
            inherit jvmOpts;

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

            files."ops.json" = {
              value = ops;
            };

            symlinks = let
              inherit (builtins) attrValues;
              inherit (pkgs) linkFarmFromDrvs fetchurl;
            in {
              mods = linkFarmFromDrvs "mods" (attrValues {
                FabricApi = fetchurl { url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/ZNwYCTsk/fabric-api-0.118.0%2B1.21.4.jar"; sha512 = "1e0d31b6663dc2c7be648f3a5a9cf7b698b9a0fd0f7ae16d1d3f32d943d7c5205ff63a4f81b0c4e94a8997482cce026b7ca486e99d9ce35ac069aeb29b02a30d"; };
                Terralith = fetchurl { url = "https://cdn.modrinth.com/data/8oi3bsk5/versions/MuJMtPGQ/Terralith_1.21.x_v2.5.8.jar"; sha512 = "f862ed5435ce4c11a97d2ea5c40eee9f817c908f3223b5fd3e3fff0562a55111d7429dc73a2f1ca0b1af7b1ff6fa0470ed6efebb5de13336c40bb70fb357dd60"; };
                # DistantHorizons = fetchurl { url = "https://cdn.modrinth.com/data/uCdwusMi/versions/jptcCdp2/DistantHorizons-2.2.1-a-1.20.4-forge-fabric.jar"; sha512 = "47368d91099d0b5f364339a69f4e425f8fb1e3a7c3250a8b649da76135e68a22f1a76b191c87e15a5cdc0a1d36bc57f2fa825490d96711d09d96807be97d575d"; };
              });
            };
          };

          tekxit = let
            inherit (pkgs) fetchzip;

            src = fetchzip {
              url = "https://tekxit.b-cdn.net/downloads/tekxit4/12.0.0Tekxit4Server.zip";
              hash = "sha256-4NqeMGOpji/gMH8XX8RemkBAOB9ID/i1S3/xXgD23to=";
              stripRoot = true;
            };
          in {
            enable = true;
            autoStart = true;
            restart = "no";
            inherit whitelist;
            inherit jvmOpts;

            package = pkgs.fabricServers.fabric-1_19_2.override { loaderVersion = "0.16.9"; };

            serverProperties = {
              gamemode = "survival";
              difficulty = 3;
              motd = "Chris' vanilla server";
              white-list = true;
              simulation-distance = 10;
              server-port = 25502;
              level-name = "world";

              allow-flight = true;
              enable-command-block = true;
              enforce-whitelist = true;
              spawn-protection = 0;
            };

            files = let
              inherit (builtins) readFile listToAttrs attrNames readDir mapAttrs;
              inherit (lib.attrsets) nameValuePair;
              inherit (lib) concatMapAttrs;
              inherit (lib.my) mapFilterAttrs;

              readDirRec = src: dir: fn:
                concatMapAttrs (name: type: if type == "directory"
                  then (readDirRec src "${dir}/${name}" fn)
                  else { "${dir}/${name}" = (fn "${dir}/${name}"); }
                ) (readDir "${src}/${dir}");

              copyDir = dir: readDirRec src dir (x: "${src}/${x}");
            in {
              "ops.json" = {
                value = ops;
              };
            }
            // (copyDir "config");

            symlinks = let
              inherit (builtins) attrNames readDir map;
              inherit (pkgs) linkFarm fetchzip;

              linkFarmFromDir = name: dir: linkFarm name (map (x: { name = x; path = "${src}/${dir}/${x}"; }) (attrNames (readDir "${src}/${dir}")));
            in {
              Deftu = linkFarmFromDir "tekxit-deftu" "Deftu";
              TKXAddons = linkFarmFromDir "tekxit-TKXAddons" "TKXAddons";
              mods = linkFarmFromDir "tekxit-mods" "mods";
              scripts = linkFarmFromDir "tekxit-scripts" "scripts";
            };
          };
        };
      };
    };
  };
}
