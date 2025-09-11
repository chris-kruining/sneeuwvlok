{ config, lib, pkgs, namespace, ... }:
let
  inherit (builtins) toString toJSON;
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.communication.conduit;

  domain = "kruining.eu";
  fqn = "matrix.${domain}";
  port = 4001;

  database = "synapse";
in
{
  options.${namespace}.services.communication.conduit = {
    enable = mkEnableOption "conduit (Matrix server)";
  };

  config = mkIf cfg.enable {
    # ${namespace}.services = {
    #   persistance.postgresql.enable = true;
    #   virtualisation.podman.enable = true;
    # };

    networking.firewall.allowedTCPPorts = [ 4001 8448 ];

    services = {
      matrix-conduit = {
        enable = false;

        settings.global = {
          address = "::";
          port = port;

          server_name = domain;

          database_backend = "rocksdb";
          # database_path = "/var/lib/matrix-conduit/";

          allow_check_for_updates = false;
          allow_registration = false;

          enable_lightning_bolt = false;
        };
      };

      matrix-synapse = {
        enable = true;

        extras = [ "oidc" ];
        plugins = with config.services.matrix-synapse.package.plugins; [];

        settings = {
          server_name = domain;
          public_baseurl = "https://${fqn}";

          enable_registration = false;
          registration_shared_secret = "tZtBnlhEmLbMwF0lQ112VH1Rl5MkZzYH9suI4pEoPXzk6nWUB8FJF4eEnwLkbstz";
          
          url_preview_enabled = true;
          precence.enabled = true;

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
            port = 40011;
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
            port = 40012;
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
