{
  pkgs,
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.${namespace}.services.observability.grafana;
  oidc = config.${namespace}.services.authentication.zitadel.organization.nix.project.ulmo.application.grafana;

  # Grafana is only reachable on the local network (or over the vpn)
  rootUrl = "http://${config.networking.hostName}:9010";

  db_user = "grafana";
  db_name = "grafana";

  datasources = [
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
  ]
  ++ lib.optionals config.${namespace}.services.observability.alertmanager.enable [
    {
      name = "Alertmanager";
      uid = "alertmanager";
      type = "alertmanager";
      url = "http://[::1]:${toString config.services.prometheus.alertmanager.port}";
      editable = false;
      jsonData = {
        implementation = "prometheus";
        handleGrafanaManagedAlerts = false;
      };
    }
  ];
in {
  options.${namespace}.services.observability.grafana = {
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
            domain = config.networking.hostName;
            root_url = rootUrl;
          };

          security = {
            secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
          };

          auth = {
            disable_login_form = false;
          };

          "auth.basic".enabled = false;
          "auth.generic_oauth" = {
            enabled = true;
            name = "Zitadel";
            # Handed over by LoadCredential below
            client_id = "$__file{/run/credentials/grafana.service/oidc_client_id}";
            client_secret = "$__file{/run/credentials/grafana.service/oidc_client_secret}";
            scopes = "openid email profile offline_access urn:zitadel:iam:org:project:roles";
            email_attribute_path = "email";
            login_attribute_path = "preferred_username";
            name_attribute_path = "name";
            # Zitadel hands the project roles over as an object keyed by role name
            role_attribute_path = "contains(keys(\"urn:zitadel:iam:org:project:roles\" || `{}`), 'grafana_admin') && 'GrafanaAdmin' || contains(keys(\"urn:zitadel:iam:org:project:roles\" || `{}`), 'grafana_editor') && 'Editor' || 'Viewer'";
            auth_url = "${config.${namespace}.services.authentication.zitadel.issuer}/oauth/v2/authorize";
            token_url = "${config.${namespace}.services.authentication.zitadel.issuer}/oauth/v2/token";
            api_url = "${config.${namespace}.services.authentication.zitadel.issuer}/oidc/v1/userinfo";
            allow_sign_up = true;
            auto_login = true;
            use_pkce = true;
            use_refresh_token = true;
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

          # Grafana only updates provisioned data sources it finds in its database, so the database
          # can drift from this config (e.g. a changed uid stops Grafana from starting). Deleting them
          # first makes Grafana recreate them from this config on every start, deletes run before inserts.
          datasources.settings = {
            deleteDatasources =
              map (datasource: {
                inherit (datasource) name;
                orgId = 1;
              })
              datasources;

            inherit datasources;
          };
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

    ${namespace}.services.authentication.zitadel.organization.nix.project.ulmo.application.grafana = {
      redirectUris = ["${rootUrl}/login/generic_oauth"];
      # The redirect uri is plain http
      devMode = true;
      restartUnits = ["grafana.service"];
    };

    # The client credentials are written by tofu-zitadel
    systemd.services.grafana.serviceConfig.LoadCredential = [
      "oidc_client_id:${oidc.directory}/client_id"
      "oidc_client_secret:${oidc.directory}/client_secret"
    ];

    sops = {
      secrets = {
        "grafana/secret_key" = {
          owner = "grafana";
          group = "grafana";
        };
      };
    };
  };
}
