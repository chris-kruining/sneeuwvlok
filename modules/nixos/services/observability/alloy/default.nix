{ config, lib, namespace, ... }:
let
  inherit (builtins) toString;
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.observability.alloy;

  httpPort = 9007;
  otlpGrpcPort = 9010;
  otlpHttpPort = 9011;
  tempoOtlpGrpcPort = 9009;
in
{
  options.${namespace}.services.observability.alloy = {
    enable = mkEnableOption "enable Grafana Alloy";
  };

  config = mkIf cfg.enable {
    services.alloy = {
      enable = true;
      configPath = "/etc/alloy";
      extraFlags = [
        "--disable-reporting"
        "--server.http.listen-addr=0.0.0.0:${toString httpPort}"
        "--storage.path=/var/lib/alloy"
      ];
    };

    environment.etc."alloy/config.alloy".text = ''
      otelcol.receiver.otlp "default" {
        grpc {
          endpoint = "127.0.0.1:${toString otlpGrpcPort}"
        }

        http {
          endpoint = "127.0.0.1:${toString otlpHttpPort}"
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
          url = "http://127.0.0.1:${toString config.services.prometheus.port}/api/v1/write"
        }
      }

      otelcol.exporter.otlp "tempo" {
        client {
          endpoint = "127.0.0.1:${toString tempoOtlpGrpcPort}"

          tls {
            insecure = true
          }
        }
      }
    '';

    networking.firewall.allowedTCPPorts = [ httpPort ];
  };
}
