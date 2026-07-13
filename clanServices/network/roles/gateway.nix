{
  lib,
  self,
}: {
  description = "Render public ingress";
  interface = import ../interfaces/gateway.nix;

  perInstance = {
    machine,
    settings,
    ...
  }: let
    clanDomain = self.clan.meta.domain;

    renderFunctions = functions:
      functions
      |> lib.map (name: settings.functions.${name}.body)
      |> lib.join "\n";

    serviceRoutes =
      settings.services
      |> lib.mapAttrsToList (_: service: service)
      |> lib.concatMap (service:
        service.routes
        |> lib.mapAttrsToList (routeName: route: {
          host =
            if lib.hasInfix "." route.host
            then route.host
            else if routeName == "default"
            then "${service.name}.${machine.name}.${clanDomain}"
            else "${route.host}.${machine.name}.${clanDomain}";
          inherit (route) functions;
          endpoint = service.endpoint;
          extraConfig = "";
        }));

    explicitRoutes =
      settings.routes
      |> lib.mapAttrsToList (_: route: route);

    routes =
      serviceRoutes
      ++ explicitRoutes
      |> lib.map (route: {
        name = route.host;
        value.extraConfig = ''
          ${renderFunctions route.functions}
          reverse_proxy ${toString route.endpoint}
          ${route.extraConfig}
        '';
      })
      |> lib.listToAttrs;
  in {
    nixosModule = {
      lib,
      pkgs,
      ...
    }: let
      inherit (lib) mkMerge;
    in {
      config = mkMerge [
        (lib.mkIf (settings.driver == "caddy") {
          services.caddy = {
            enable = true;
            package = self.packages.${pkgs.stdenv.hostPlatform.system}.caddy;

            virtualHosts =
              (settings.hosts
                |> lib.mapAttrs (_: extraConfig: {inherit extraConfig;}))
              // routes;
          };
        })
      ];
    };
  };
}
