{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.observability.tempo;

  httpPort = 9060;
  grpcPort = 9061;
  otlpGrpcPort = 9062;
  otlpHttpPort = 9063;
in {
  options.${namespace}.services.observability.tempo = {
    enable = mkEnableOption "enable Grafana Tempo";
  };

  config = mkIf cfg.enable {
    services.tempo = {
      enable = true;
      settings = {
        auth_enabled = false;

        # Only Grafana and Alloy talk to Tempo, both on this machine.
        # Tempo brackets the address itself. gRPC stays on IPv4 because in single binary mode
        # the scheduler and querier workers dial 127.0.0.1:<grpc port>.
        server = {
          http_listen_address = "::1";
          http_listen_port = httpPort;
          grpc_listen_address = "127.0.0.1";
          grpc_listen_port = grpcPort;
        };

        distributor.receivers.otlp.protocols = {
          grpc.endpoint = "[::1]:${builtins.toString otlpGrpcPort}";
          http.endpoint = "[::1]:${builtins.toString otlpHttpPort}";
        };

        storage.trace = {
          backend = "local";
          wal.path = "/var/lib/tempo/wal";
          local.path = "/var/lib/tempo/traces";
        };

        # These default to /var/tempo, which the unit (DynamicUser) can't write to
        live_store = {
          shutdown_marker_dir = "/var/lib/tempo/live-store/shutdown-marker";
          wal.path = "/var/lib/tempo/live-store/traces";
        };
        backend_scheduler.local_work_path = "/var/lib/tempo/work";

        backend_worker.compaction.block_retention = "168h";
      };
    };
  };
}
