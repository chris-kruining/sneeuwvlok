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
        search_enabled = true;

        server = {
          http_listen_address = "[::]";
          http_listen_port = httpPort;
          grpc_listen_address = "[::1]";
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

        compactor.compaction.block_retention = "168h";
      };
    };

    networking.firewall.allowedTCPPorts = [httpPort];
  };
}
