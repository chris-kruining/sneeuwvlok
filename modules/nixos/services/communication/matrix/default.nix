{ config, lib, pkgs, namespace, ... }:
let
  inherit (builtins) toString toJSON;
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.communication.matrix;

  domain = "kruining.eu";
  fqn = "matrix.${domain}";
  port = 4001;

  database = "synapse";
in
{
  options.${namespace}.services.communication.matrix = {
    enable = mkEnableOption "Matrix server (Synapse)";
  };

  config = mkIf cfg.enable {
    ${namespace}.services = {
      persistance.postgresql.enable = true;
      # virtualisation.podman.enable = true;
    };

    networking.firewall.allowedTCPPorts = [ 4001 ];

    services = {
      matrix-synapse = {
        enable = true;

        extras = [ "oidc" ];
        # plugins = with config.services.matrix-synapse.package.plugins; [];

        settings = {
          server_name = domain;
          public_baseurl = "https://${fqn}";

          registration_shared_secret = "tZtBnlhEmLbMwF0lQ112VH1Rl5MkZzYH9suI4pEoPXzk6nWUB8FJF4eEnwLkbstz";

          url_preview_enabled = true;
          precence.enabled = true;

          # Since we'll be using OIDC for auth disable all local options
          enable_registration = false;
          password_config.enabled = false;

          sso = {
            client_whitelist = [ "http://[::1]:9092" ];
            update_profile_information = true;
          };

          oidc_providers = [
            {
              discover = true;

              idp_id = "zitadel";
              idp_name = "Zitadel";
              issuer = "https://auth.amarth.cloud";
              client_id = "337858153251143939";
              client_secret = "ePkf5n8BxGD5DF7t1eNThTL0g6PVBO5A1RC0EqPp61S7VsiyXvDs8aJeczrpCpsH";
              scopes = [ "openid" "profile" ];
              # user_mapping_provider.config = {
              #   localpart_template = "{{ user.prefered_username }}";
              #   display_name_template = "{{ user.name }}";
              # };
            }
          ];

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
                  names = [ "client" "federation" ];
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
            # port = 40011;
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
            # port = 40012;
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
        ensureDatabases = [ database ];
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
            "m.identity_server".base_url = "https://auth.amarth.cloud";
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
  };
}
