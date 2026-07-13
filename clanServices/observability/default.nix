{lib, ...}: {
  _class = "clan.service";
  manifest = {
    name = "observability";
    description = "Foundational observability stack";
    categories = ["Service" "Observability"];
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["observability"];
      out = ["gateway" "identity" "observability" "persistence"];
    };
  };

  roles.default = {
    description = "Grafana-based observability stack";
    interface = import ./interface.nix;

    perInstance = {
      settings,
      mkExports,
      ...
    }: {
      exports = mkExports {
        persistence.databases = lib.optional settings.grafana.grafana.enable "grafana";
        gateway.services.grafana = lib.mkIf settings.grafana.grafana.enable {
          endpoint.port = settings.grafana.ports.grafana;
        };
        identity.applications.grafana = lib.mkIf (settings.identity.provider != null && settings.grafana.host != null) {
          provider = settings.identity.provider;
          redirectUris = ["https://${settings.grafana.host}${settings.grafana.oidcCallbackPath}"];
        };
        observability = {
          metrics = settings.metrics;
          logs = settings.logs;
          traces = settings.traces;
        };
      };

      nixosModule = {lib, ...}: {
        config = lib.mkIf (settings.driver == "grafana") {
          services = {
            grafana.enable = settings.grafana.grafana.enable;
            prometheus.enable = settings.grafana.prometheus.enable;
            loki.enable = settings.grafana.loki.enable;
            tempo.enable = settings.grafana.tempo.enable;
            alloy.enable = settings.grafana.alloy.enable;
          };
        };
      };
    };
  };
}
