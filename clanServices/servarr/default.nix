{
  exports,
  clanLib,
  lib,
  ...
}: let
  inherit (lib) toString;
in {
  _class = "clan.service";
  manifest = {
    name = "arda/servarr";
    description = '''';
    categories = ["Service" "Media"];
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["persistence"];
      out = ["gateway" "persistence"];
    };
  };

  roles.default = {
    description = '''';

    interface = import ./interface.nix;

    perInstance = {
      instanceName,
      settings,
      machine,
      roles,
      mkExports,
      ...
    }: {
      exports = mkExports {
        # endpoints.hosts =
        #   settings.services
        #   |> lib.attrNames
        #   |> (s: lib.concat s ["sabnzbd" "qbittorrent" "flaresolverr"])
        #   |> lib.map (service: "${service}.${machine.name}.arda");

        persistence.databases =
          settings.services
          |> lib.attrNames;

        gateway.services =
          settings.services
          |> lib.attrNames
          # |> (s: lib.concat s ["sabnzbd" "qbittorrent" "flaresolverr"])
          |> lib.imap1 (i: name: {
            inherit name;
            value = {
              endpoint.port = 2000 + i;
            };
          })
          |> lib.listToAttrs;
      };

      nixosModule = args @ {
        config,
        lib,
        pkgs,
        ...
      }: let
        services = settings.services |> lib.attrNames;
        service_count = services |> lib.length;

        servarr = import ./lib.nix (args // {inherit settings;});
      in {
        imports = [
          (import ./sabnzbd.nix (args
            // {
              inherit settings;
              port = 2000 + service_count + 1;
            }))
          (import ./qbittorrent.nix (args
            // {
              inherit settings;
              port = 2000 + service_count + 2;
            }))
          (servarr.createModule settings.services)
        ];

        config = {
          clan.core.vars.generators.servarr = rec {
            dependencies =
              services ++ ["sabnzbd" "qbittorrent"];

            files."config.tfvars" = {
              owner = "media";
              group = "media";
              mode = "0440";
              restartUnits = services |> lib.map (s: "${s}.service");
            };

            script = ''
              cat << EOL > $out/config.tfvars
              ${
                services
                |> lib.map (s: "${s}_api_key = \"$(cat $in/${s}/api_key)\"")
                |> lib.join "\n"
              }
              qbittorrent_api_key = "$(cat $in/qbittorrent/password)"
              sabnzbd_api_key = "$(cat $in/sabnzbd/api_key)"
              EOL
            '';
          };

          users.groups."media" = {};

          services = {
            flaresolverr = {
              enable = true;
              openFirewall = true;
              port = 2000 + service_count + 3;
            };
          };
        };
      };
    };
  };

  perMachine = {...}: {
  };
}
