{
  lib,
  clanLib,
  exports,
  ...
}: let
  inherit (builtins) toString;
in {
  _class = "clan.service";
  manifest = {
    name = "arda/gateway";
    description = ''
    '';
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = [];
      out = [];
    };
  };

  roles.default = {
    description = '''';

    interface = {lib, ...}: let
      inherit (lib) mkOption types;
    in {
      options = {
        driver = mkOption {
          type = types.enum ["caddy" "nginx"];
        };

        hosts = mkOption {
          type = types.attrsOf types.str;
          default = {};
        };
      };
    };

    perInstance = {
      mkExports,
      machine,
      settings,
      ...
    }: let
      reverse_proxies =
        exports
        |> clanLib.selectExports (_scope: true)
        |> lib.mapAttrsToList (_: value: (value.gateway.services or {}) |> lib.attrValues)
        |> lib.concatLists
        |> lib.map ({
          name,
          endpoint,
        }: {
          name = "${name}.${machine.name}.arda";
          value = {
            extraConfig = ''
              reverse_proxy ${toString endpoint}
            '';
          };
        })
        |> lib.listToAttrs;
    in {
      # exports =
      #   mkExports {
      #   };

      nixosModule = {
        lib,
        pkgs,
        ...
      }: let
        inherit (lib) mkMerge mkIf;

        caddyPackage = pkgs.caddy.withPlugins {
          plugins = ["github.com/corazawaf/coraza-caddy/v2@v2.1.0"];
          hash = "sha256-pSXjLaZoRtKV3eFl2ySRSjl3yxi514G1Cb7pfrpxxtE=";
        };
      in {
        config = mkMerge [
          (lib.mkIf (settings.driver == "caddy") {
            services.caddy = {
              enable = true;
              package = caddyPackage;

              virtualHosts = reverse_proxies // {};
            };
          })
        ];
      };
    };
  };
}
