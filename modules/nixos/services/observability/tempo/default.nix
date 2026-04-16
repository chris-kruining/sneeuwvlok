{ config, lib, namespace, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.observability.tempo;

  httpPort = 9600;
  grpcPort = 9601;
  otlpGrpcPort = 9602;
  otlpHttpPort = 9603;
in
{
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
          http_listen_address = "0.0.0.0";
          http_listen_port = httpPort;
          grpc_listen_address = "127.0.0.1";
          grpc_listen_port = grpcPort;
        };

        distributor.receivers.otlp.protocols = {
          grpc.endpoint = "127.0.0.1:${builtins.toString otlpGrpcPort}";
          http.endpoint = "127.0.0.1:${builtins.toString otlpHttpPort}";
        };

        storage.trace = {
          backend = "local";
          wal.path = "/var/lib/tempo/wal";
          local.path = "/var/lib/tempo/traces";
        };

        compactor.compaction.block_retention = "168h";
      };
    };

    networking.firewall.allowedTCPPorts = [ httpPort ];
  };
}
