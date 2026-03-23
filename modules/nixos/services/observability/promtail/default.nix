{
  pkgs,
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.${namespace}.services.observability.promtail;
in {
  options.${namespace}.services.observability.promtail = {
    enable = mkEnableOption "enable Grafana Promtail";
  };

  config = mkIf cfg.enable {
    services.promtail = {
      enable = true;

      # Ensures proper permissions
      extraFlags = [
        "-config.expand-env=true"
      ];

      configuration = {
        server = {
          http_listen_port = 9004;
          grpc_listen_port = 0;
        };

        positions = {
          filename = "filename";
        };

        clients = [
          {
            url = "http://[::1]:9003/loki/api/v1/push";
          }
        ];

        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = "ulmo";
              };
            };
            relabel_configs = [
              {
                source_labels = ["__journal__systemd_unit"];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };

    networking.firewall.allowedTCPPorts = [9004];
  };
}
