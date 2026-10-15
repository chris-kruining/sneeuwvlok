{ pkgs, config, lib, namespace, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib) types;

  cfg = config.${namespace}.services.observability.loki;

  # Without authentication everything belongs to the tenant "fake"
  rules = pkgs.writeTextDir "fake/rules.yaml" (builtins.toJSON { groups = cfg.rules; });
in
{
  options.${namespace}.services.observability.loki = {
    enable = mkEnableOption "enable Grafana Loki";

    alertmanager = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Url of the Alertmanager the ruler sends its alerts to, the ruler only runs when this is set.
      '';
    };

    rules = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = ''
        Rule groups evaluated by the ruler, in the format of Prometheus rule groups with LogQL expressions.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;

        # Only Grafana and Alloy talk to Loki, both on this machine
        server = {
          http_listen_address = "::1";
          http_listen_port = 9030;
          grpc_listen_address = "127.0.0.1";
        };

        # The querier reaches the frontend on the address it advertises, which defaults to the LAN address
        frontend.address = "127.0.0.1";

        common = {
          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
          replication_factor = 1;
          path_prefix = config.services.loki.dataDir;
          storage.filesystem = {
            chunks_directory = "${config.services.loki.dataDir}/chunks";
            rules_directory = "${config.services.loki.dataDir}/rules";
          };
        };

        limits_config = {
          retention_period = "30d";
          # A top list per client of a day goes over the default of 500, before topk cuts it down
          max_query_series = 5000;
        };

        ruler = mkIf (cfg.alertmanager != null) {
          alertmanager_url = cfg.alertmanager;
          storage = {
            type = "local";
            local.directory = "${rules}";
          };
          rule_path = "${config.services.loki.dataDir}/ruler";
          ring.kvstore.store = "inmemory";
          enable_api = true;
        };

        compactor = {
          working_directory = "${config.services.loki.dataDir}/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
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
  };
}
