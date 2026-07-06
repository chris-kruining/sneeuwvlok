{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.sneeuwvlok.services.observability.grafana;

  db_user = "grafana";
  db_name = "grafana";
in {
  options.sneeuwvlok.services.observability.grafana = {
    enable = mkEnableOption "enable Grafana";
  };

  config = mkIf cfg.enable {
    services = {
      grafana = {
        enable = true;
        openFirewall = true;

        settings = {
          server = {
            http_port = 9010;
            http_addr = "::";
            domain = "ulmo";
          };

          security = {
            secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
          };

          auth = {
            disable_login_form = false;
          };

          "auth.basic".enable = false;
          "auth.generic_oauth" = {
            enable = true;
            name = "Zitadel";
            client_id = "$__file{${config.sops.secrets."grafana/oidc_id".path}}";
            client_secret = "$__file{${config.sops.secrets."grafana/oidc_secret".path}}";
            scopes = "openid email profile offline_access urn:zitadel:iam:org:project:roles";
            email_attribute_path = "email";
            login_attribute_path = "username";
            name_attribute_path = "full_name";
            role_attribute_path = "contains(urn:zitadel:iam:org:project:roles[*], 'owner') && 'GrafanaAdmin' || contains(urn:zitadel:iam:org:project:roles[*], 'contributer') && 'Editor' || 'Viewer'";
            auth_url = "https://auth.kruining.eu/oauth/v2/authorize";
            token_url = "https://auth.kruining.eu/oauth/v2/token";
            api_url = "https://auth.kruining.eu/oidc/v1/userinfo";
            allow_sign_up = true;
            auto_login = true;
            use_pkce = true;
            usr_refresh_token = true;
            allow_assign_grafana_admin = true;
          };

          database = {
            type = "postgres";
            host = "/var/run/postgresql:5432";
            name = db_name;
            user = db_user;
            ssl_mode = "disable";
          };

          users = {
            allow_sign_up = false;
            allow_org_create = false;
            viewers_can_edit = false;

            default_theme = "system";
          };

          analytics = {
            reporting_enabled = false;
            check_for_updates = false;
            check_for_plugin_updates = false;
            feedback_links_enabled = false;
          };
        };

        provision = {
          enable = true;

          dashboards.settings = {
            apiVersion = 1;
            providers = [
              {
                name = "Default Dashboard";
                disableDeletion = true;
                allowUiUpdates = false;
                options = {
                  path = "/etc/grafana/dashboards";
                  foldersFromFilesStructure = true;
                };
              }
            ];
          };

          datasources.settings.datasources = [
            {
              name = "Prometheus";
              uid = "prometheus";
              type = "prometheus";
              url = "http://[::1]:9020";
              isDefault = true;
              editable = false;
            }

            {
              name = "Loki";
              uid = "loki";
              type = "loki";
              url = "http://[::1]:9030";
              editable = false;
            }

            {
              name = "Tempo";
              uid = "tempo";
              type = "tempo";
              url = "http://[::1]:9060";
              editable = false;
              # jsonData = {
              #   nodeGraph.enabled = true;
              #   serviceMap.datasourceUid = "prometheus";
              #   tracesToLogsV2 = {
              #     datasourceUid = "loki";
              #     filterByTraceID = true;
              #     spanStartTimeShift = "-1h";
              #     spanEndTimeShift = "1h";
              #   };
              # };
            }
          ];
        };
      };

      postgresql = {
        enable = true;
        ensureDatabases = [db_name];
        ensureUsers = [
          {
            name = db_user;
            ensureDBOwnership = true;
          }
        ];
      };
    };

    environment.etc."/grafana/dashboards/default.json".source = ./dashboards/default.json;

    sops = {
      secrets = {
        "grafana/secret_key" = {
          owner = "grafana";
          group = "grafana";
        };
        "grafana/oidc_id" = {
          owner = "grafana";
          group = "grafana";
        };
        "grafana/oidc_secret" = {
          owner = "grafana";
          group = "grafana";
        };
      };
    };
  };
}
