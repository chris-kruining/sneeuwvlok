{ pkgs, config, lib, namespace, ... }:
let
  inherit (builtins) toString;
  inherit (lib) mkEnableOption mkIf optionals;

  cfg = config.${namespace}.services.observability.prometheus;
  services = config.${namespace}.services;
  exporters = config.services.prometheus.exporters;

  # Every exporter only listens on localhost, Prometheus is the only one reading them
  local = port: "[::1]:${toString port}";

  job = job_name: target: extra: {
    inherit job_name;
    static_configs = [
      { targets = [ target ]; }
    ];
  } // extra;

  # The servarr apps that have an exportarr instance, with the port of that instance
  arrs = {
    radarr = 9025;
    sonarr = 9026;
    lidarr = 9027;
    prowlarr = 9028;
  }
  |> lib.filterAttrs (name: _: services.media.servarr.${name}.enable or false);

  # The public sites, every caddy host is one (or more, comma separated)
  sites = config.services.caddy.virtualHosts
    |> lib.attrNames
    |> lib.concatMap (lib.splitString ", ")
    |> map (host: "https://${host}");
in
{
  options.${namespace}.services.observability.prometheus = {
    enable = mkEnableOption "enable Prometheus";
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      # Grafana is the frontend, nothing else needs to reach Prometheus
      listenAddress = "[::1]";
      port = 9020;
      retentionTime = "90d";
      extraFlags = optionals services.observability.alloy.enable [
        "--web.enable-remote-write-receiver"
      ];

      globalConfig.scrape_interval = "15s";

      scrapeConfigs = [
        (job "prometheus" (local 9020) {})
        (job "node" (local exporters.node.port) {})
        (job "smartctl" (local exporters.smartctl.port) {})
        (job "postgres" (local exporters.postgres.port) {})

        {
          job_name = "blackbox";
          metrics_path = "/probe";
          params.module = [ "https" ];
          static_configs = [
            { targets = sites; }
          ];
          # Hand the site over to blackbox as a parameter, and scrape blackbox itself
          relabel_configs = [
            { source_labels = [ "__address__" ]; target_label = "__param_target"; }
            { source_labels = [ "__param_target" ]; target_label = "instance"; }
            { target_label = "__address__"; replacement = local exporters.blackbox.port; }
          ];
        }
      ]
      ++ optionals config.services.caddy.enable [
        (job "caddy" "127.0.0.1:2019" {})
      ]
      ++ optionals services.development.forgejo.enable [
        (job "forgejo" "127.0.0.1:${toString config.services.forgejo.settings.server.HTTP_PORT}" {})
      ]
      ++ optionals services.communication.matrix.enable [
        (job "synapse" (local (lib.head config.services.matrix-synapse.settings.listeners).port) {
          metrics_path = "/_synapse/metrics";
        })
      ]
      ++ optionals services.authentication.zitadel.enable [
        (job "zitadel" (local config.services.zitadel.settings.Port) {
          metrics_path = "/debug/metrics";
        })
      ]
      ++ optionals services.observability.alloy.enable [
        (job "alloy" (local 9070) {})
      ]
      ++ optionals services.observability.tempo.enable [
        (job "tempo" (local 9060) {})
      ]
      ++ lib.mapAttrsToList (name: _: job name (local exporters."exportarr-${name}".port) {}) arrs;

      exporters = {
        node = {
          enable = true;
          listenAddress = "[::1]";
          port = 9021;
          enabledCollectors = [ "systemd" "processes" ];
          extraFlags = [
            # Restart loops, and when a (backup) job last ran
            "--collector.systemd.enable-restarts-metrics"
            "--collector.systemd.enable-start-time-metrics"
          ];
        };

        smartctl = {
          enable = true;
          listenAddress = "[::1]";
          port = 9022;
        };

        postgres = {
          enable = true;
          listenAddress = "[::1]";
          port = 9023;
          runAsLocalSuperUser = true;
        };

        blackbox = {
          enable = true;
          listenAddress = "[::1]";
          port = 9024;
          configFile = pkgs.writeText "blackbox.yml" (builtins.toJSON {
            modules.https = {
              prober = "http";
              timeout = "10s";
              http = {
                fail_if_not_ssl = true;
                follow_redirects = true;
                preferred_ip_protocol = "ip4";
              };
            };
          });
        };
      }
      // (arrs |> lib.mapAttrs' (name: port: lib.nameValuePair "exportarr-${name}" {
        enable = true;
        listenAddress = "[::1]";
        inherit port;
        url = "http://127.0.0.1:${toString services.media.servarr.${name}.port}";
        apiKeyFile = config.sops.secrets."${name}/apikey".path;
      }));
    };
  };
}
