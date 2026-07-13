{inputs, ...}: {
  imports = [];

  perSystem = {
    system,
    pkgs,
    lib,
    ...
  }: let
    endpointsLib = import ../lib/endpoints.nix {inherit lib;};

    fakeClanLib.getExport = _scope: exports: exports."network:network:default:ulmo";

    helperFixture = let
      exports."network:network:default:ulmo".ports.assigned = {
        "servarr/default/radarr" = 20001;
        "servarr/default/sonarr" = 20000;
      };

      endpointService = endpointsLib.forService {
        inherit exports;
        clanLib = fakeClanLib;
        machine.name = "ulmo";
        serviceName = "servarr";
        instanceName = "default";
      };
    in
      endpointService.internal ["sonarr" "radarr"];

    exhaustedRange =
      builtins.tryEval
      (builtins.deepSeq
        (endpointsLib.assignPorts {
          machineName = "ulmo";
          range = {
            start = 20000;
            end = 20000;
          };
          claimNames = ["a" "b"];
        })
        true);

    gatewayFixture = let
      fakeSelf = {
        clan.meta.domain = "example.test";
        packages.${system}.caddy = pkgs.caddy;
      };
      gatewayRole = import ../clanServices/network/roles/gateway.nix {
        inherit lib;
        self = fakeSelf;
      };
      endpoint = helperFixture.sonarr // {__toString = endpoint: "http://localhost:${toString endpoint.port}";};
      result =
        gatewayRole.perInstance {
          machine.name = "ulmo";
          settings = {
            driver = "caddy";
            hosts = {};
            functions = {};
            services.sonarr = {
              name = "sonarr";
              inherit endpoint;
              routes.default = {
                host = "default";
                functions = [];
              };
            };
            routes = {};
          };
        };
      caddyConfig =
        (result.nixosModule {inherit lib pkgs;}).config.contents
        |> builtins.head
        |> (v: v.content.services.caddy);
    in
      caddyConfig.virtualHosts."sonarr.ulmo.example.test".extraConfig;
  in {
    packages = {
      caddy = pkgs.callPackage ./caddy {corazaCaddy = inputs.coraza-caddy;};
      studio = pkgs.callPackage ./studio {erosanix = inputs.erosanix.lib.${system};};
    };

    checks.network =
      assert helperFixture.claims == {
        "servarr/default/radarr" = {};
        "servarr/default/sonarr" = {};
      };
      assert helperFixture.sonarr.port == 20000;
      assert helperFixture.radarr.port == 20001;
      assert exhaustedRange.success == false;
      assert lib.hasInfix "reverse_proxy http://localhost:20000" gatewayFixture;
        pkgs.runCommand "network-check" {} ''
          touch $out
        '';
  };
}
