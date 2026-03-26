{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.sneeuwvlok.services.observability.loki;
in {
  options.sneeuwvlok.services.observability.loki = {
    enable = mkEnableOption "enable Grafana Loki";
  };

  config = mkIf cfg.enable {
    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;

        server = {
          http_listen_port = 9003;
        };

        common = {
          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
          replication_factor = 1;
          path_prefix = "/tmp/loki";
        };

        schema_config.configs = [
          {
            from = "2025-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };
    };

    networking.firewall.allowedTCPPorts = [9003];
  };
}
