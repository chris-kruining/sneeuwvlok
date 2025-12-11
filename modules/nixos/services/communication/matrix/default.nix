{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (builtins) toString toJSON;
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.communication.matrix;

  domain = "kruining.eu";
  fqn = "matrix.${domain}";
  port = 4001;

  database = "synapse";
in {
  options.${namespace}.services.communication.matrix = {
    enable = mkEnableOption "Matrix server (Synapse)";
  };

  config = mkIf cfg.enable {
    ${namespace}.services = {
      persistance.postgresql.enable = true;
      # virtualisation.podman.enable = true;
    };

    networking.firewall.allowedTCPPorts = [4001];

    services = {
      matrix-synapse = {
        enable = true;

        extras = ["oidc"];

        extraConfigFiles = [
          config.sops.templates."synapse-oidc.yaml".path
        ];

        settings = {
          server_name = domain;
          public_baseurl = "https://${fqn}";

          enable_metrics = true;

          registration_shared_secret = "tZtBnlhEmLbMwF0lQ112VH1Rl5MkZzYH9suI4pEoPXzk6nWUB8FJF4eEnwLkbstz";

          url_preview_enabled = true;
          precence.enabled = true;

          # Since we'll be using OIDC for auth disable all local options
          enable_registration = false;
          enable_registration_without_verification = false;
          password_config.enabled = false;
          backchannel_logout_enabled = true;

          sso = {
            client_whitelist = ["http://[::1]:9092"];
            update_profile_information = true;
          };

          database = {
            # this is postgresql (also the default, but I prefer to be explicit)
            name = "psycopg2";
            args = {
              database = database;
              user = database;
            };
          };

          listeners = [
            {
              bind_addresses = ["::"];
              port = port;
              type = "http";
              tls = false;
              x_forwarded = true;

              resources = [
                {
                  names = ["client" "federation" "openid" "metrics" "media" "health"];
                  compress = true;
                }
              ];
            }
          ];
        };
      };

      mautrix-signal = {
        enable = true;
        registerToSynapse = true;

        settings = {
          appservice = {
            provisioning.enabled = false;
          };

          homeserver = {
            address = "http://[::1]:${toString port}";
            domain = domain;
          };

          bridge = {
            permissions = {
              "@chris:${domain}" = "admin";
            };
          };
        };
      };

      mautrix-whatsapp = {
        enable = true;
        registerToSynapse = true;

        settings = {
          appservice = {
            provisioning.enabled = false;
          };

          homeserver = {
            address = "http://[::1]:${toString port}";
            domain = domain;
          };

          bridge = {
            permissions = {
              "@chris:${domain}" = "admin";
            };
          };
        };
      };

      postgresql = {
        enable = true;
        ensureDatabases = [database];
        ensureUsers = [
          {
            name = database;
            ensureDBOwnership = true;
          }
        ];
      };

      caddy = {
        enable = true;
        virtualHosts = let
          server = {
            "m.server" = "${fqn}:443";
          };
          client = {
            "m.homeserver".base_url = "https://${fqn}";
            "m.identity_server".base_url = "https://auth.kruining.eu";
          };
        in {
          "${domain}".extraConfig = ''
            header /.well-known/matrix/* Content-Type application/json
            header /.well-known/matrix/* Access-Control-Allow-Origin *
            respond /.well-known/matrix/server `${toJSON server}`
            respond /.well-known/matrix/client `${toJSON client}`
          '';
          "${fqn}".extraConfig = ''
            reverse_proxy /_matrix/* http://::1:4001
            reverse_proxy /_synapse/client/* http://::1:4001
          '';
        };
      };
    };

    sops = {
      secrets = {
        "synapse/oidc_id" = {};
        "synapse/oidc_secret" = {};
      };

      templates = {
        "synapse-oidc.yaml" = {
          owner = "matrix-synapse";
          content = ''
            oidc_providers:
              - discover: true
                idp_id: zitadel
                idp_name: Zitadel
                issuer: "https://auth.kruining.eu"
                scopes:
                  - openid
                  - profile
                client_id: '${config.sops.placeholder."synapse/oidc_id"}'
                client_secret: '${config.sops.placeholder."synapse/oidc_secret"}'
                backchannel_logout_enabled: true
                user_mapping_provider:
                  config:
                    localpart_template: "{{ user.preferred_username }}"
                    display_name_template: "{{ user.name }}"
          '';
          restartUnits = ["matrix-synapse.service"];
        };
      };
    };
  };
}
