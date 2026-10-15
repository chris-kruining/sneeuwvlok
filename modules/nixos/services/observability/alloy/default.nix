{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.observability.alloy;

  httpPort = 9070;
  otlpGrpcPort = 9071;
  otlpHttpPort = 9072;
  tempoOtlpGrpcPort = 9062;
  lokiPort = 9030;
in {
  options.${namespace}.services.observability.alloy = {
    enable = mkEnableOption "enable Grafana Alloy";
  };

  config = mkIf cfg.enable {
    services.alloy = {
      enable = true;
      configPath = "/etc/alloy";
      extraFlags = [
        "--disable-reporting"
        "--server.http.listen-addr=[::1]:${toString httpPort}"
        "--storage.path=/var/lib/alloy"
      ];
    };

    environment.etc."alloy/config.alloy".text = ''
      otelcol.receiver.otlp "default" {
        grpc {
          endpoint = "[::1]:${toString otlpGrpcPort}"
        }

        http {
          endpoint = "[::1]:${toString otlpHttpPort}"
        }

        output {
          metrics = [otelcol.processor.batch.metrics.input]
          traces  = [otelcol.processor.batch.traces.input]
        }
      }

      otelcol.processor.batch "metrics" {
        output {
          metrics = [otelcol.exporter.prometheus.default.input]
        }
      }

      otelcol.processor.batch "traces" {
        output {
          traces = [otelcol.exporter.otlp.tempo.input]
        }
      }

      otelcol.exporter.prometheus "default" {
        forward_to = [prometheus.remote_write.local.receiver]
      }

      prometheus.remote_write "local" {
        endpoint {
          url = "http://[::1]:${toString config.services.prometheus.port}/api/v1/write"
        }
      }

      otelcol.exporter.otlp "tempo" {
        client {
          endpoint = "[::1]:${toString tempoOtlpGrpcPort}"

          tls {
            insecure = true
          }
        }
      }

      loki.write "local" {
        endpoint {
          url = "http://[::1]:${toString lokiPort}/loki/api/v1/push"
        }
      }

      // The journal of every unit
      loki.relabel "journal" {
        forward_to = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }

        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }

        rule {
          source_labels = ["__journal_syslog_identifier"]
          target_label  = "identifier"
        }
      }

      loki.source.journal "default" {
        max_age       = "12h"
        relabel_rules = loki.relabel.journal.rules
        labels        = {job = "journal", host = "${config.networking.hostName}"}
        forward_to    = [loki.write.local.receiver]
      }

      // The access logs of caddy, one file per host
      local.file_match "caddy" {
        path_targets = [{
          __path__ = "${config.services.caddy.logDir}/access-*.log",
          job      = "caddy",
          host     = "${config.networking.hostName}",
        }]
      }

      loki.source.file "caddy" {
        targets    = local.file_match.caddy.targets
        // Some of the files go back years, older entries than loki accepts
        tail_from_end = true
        forward_to = [loki.process.caddy.receiver]
      }

      loki.process "caddy" {
        stage.regex {
          source     = "filename"
          expression = "access-(?P<vhost>.+)\\.log$"
        }

        stage.labels {
          values = {vhost = ""}
        }

        stage.label_drop {
          values = ["filename"]
        }

        forward_to = [loki.write.local.receiver]
      }
    '';

    # Caddy's access logs are only readable by its group
    systemd.services.alloy.serviceConfig.SupplementaryGroups = ["caddy"];
  };
}
