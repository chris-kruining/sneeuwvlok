{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (builtins) toString toJSON;
  inherit (lib) mkIf mkEnableOption mkMerge;

  cfg = config.${namespace}.services.communication.matrix;

  domain = "kruining.eu";
  fqn = "matrix.${domain}";
  port = 4001;

  database = "synapse";
  keyFile = "/var/lib/element-call/key";

  mkMautrix = bridge: i: conf: {
    ${bridge} = mkMerge [
      {
        enable = true;
        registerToSynapse = true;

        settings = {
          appservice = {
            # hostname = "[::]";
            # port = 40010 + i;
            # address = "http://${config.services.${bridge}.settings.appservice.hostname}:${toString config.services.${bridge}.settings.appservice.port}";
            provisioning.enabled = false;
          };

          homeserver = {
            inherit domain;
            address = "http://[::1]:${toString port}";
          };

          bridge = {
            permissions = {
              "@chris:${domain}" = "admin";
            };
          };
        };
      }
      conf
    ];
  };
in {
  options.${namespace}.services.communication.matrix = {
    enable = mkEnableOption "Matrix server (Synapse)";
  };

  config = mkIf cfg.enable {
    ${namespace}.services = {
      persistance.postgresql.enable = true;

      networking.caddy = {
        hosts = let
          server = {
            "m.server" = "${fqn}:443";
          };
          client = {
            "m.homeserver".base_url = "https://${fqn}";
            "m.identity_server".base_url = "https://auth.${domain}";
            "org.matrix.msc3575.proxy".url = "https://${domain}";
            "org.matrix.msc4143.rtc_foci" = [
              {
                type = "livekit";
                livekit_service_url = "https://${domain}/livekit/jwt";
              }
            ];
          };
        in {
          "${domain}, darkch.at" = ''
            # Route for lk-jwt-service
            handle /livekit/jwt* {
              uri strip_prefix /livekit/jwt
              reverse_proxy http://[::1]:${toString config.services.lk-jwt-service.port} {
                header_up Host {host}
                header_up X-Forwarded-Server {host}
                header_up X-Real-IP {remote_host}
                header_up X-Forwarded-For {remote_host}
              }
            }

            handle_path /livekit/sfu* {
              reverse_proxy http://[::1]:${toString config.services.livekit.settings.port} {
                header_up Host {host}
                header_up X-Forwarded-Server {host}
                header_up X-Real-IP {remote_host}
                header_up X-Forwarded-For {remote_host}
              }
            }

            header /.well-known/matrix/* Content-Type application/json
            header /.well-known/matrix/* Access-Control-Allow-Origin *
            respond /.well-known/matrix/server `${toJSON server}`
            respond /.well-known/matrix/client `${toJSON client}`
          '';

          "${fqn}" = ''
            reverse_proxy /_matrix/* http://[::1]:${toString port}
            reverse_proxy /_synapse/client/* http://[::1]:${toString port}
          '';
        };
      };
    };

    services = mkMerge [
      (mkMautrix "mautrix-signal" 1 {})
      (mkMautrix "mautrix-telegram" 2 {})
      (mkMautrix "mautrix-whatsapp" 3 {})
      (mkMautrix "arrtrix" 4 {
        settings.network.webhooks.radarr = {
          enabled = true;
          path = "/_arrtrix/webhooks/radarr";
          secret = "";
        };
      })
      {
        matrix-synapse = {
          enable = true;

          extras = ["oidc"];

          extraConfigFiles = [
            config.sops.templates."synapse.yaml".path
            config.sops.templates."synapse-oidc.yaml".path
          ];

          settings = {
            server_name = domain;
            public_baseurl = "https://${fqn}";

            enable_metrics = true;

            url_preview_enabled = true;
            precence.enabled = true;

            # Since we'll be using OIDC for auth disable all local options
            enable_registration = false;
            enable_registration_without_verification = false;
            password_config.enabled = true;
            backchannel_logout_enabled = true;

            # Element Call options
            max_event_delay_duration = "24h";
            rc_message = {
              per_second = 0.5;
              burst_count = 30;
            };
            rc_delayed_event_mgmt = {
              per_second = 1;
              burst_count = 20;
            };
            turn_uris = ["turn:turn.${domain}:4004?transport=udp" "turn:turn.${domain}:4004?transport=tcp"];

            experimental_features = {
              # MSC2965: OAuth 2.0 Authorization Server Metadata discovery
              msc2965_enabled = true;

              # MSC3266: Room summary API. Used for knocking over federation
              msc3266_enabled = true;
              # MSC4222 needed for syncv2 state_after. This allow clients to
              # correctly track the state of the room.
              msc4222_enabled = true;
            };

            sso = {
              client_whitelist = ["http://[::1]:9092/" "https://auth.kruining.eu/"];
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

        postgresql = {
          ensureDatabases = [database];
          ensureUsers = [
            {
              name = database;
              ensureDBOwnership = true;
            }
          ];
        };

        livekit = {
          enable = true;
          openFirewall = true;
          inherit keyFile;

          settings = {
            port = 4002;
            room.auto_create = false;
          };
        };

        lk-jwt-service = {
          enable = true;
          port = 4003;
          # can be on the same virtualHost as synapse
          livekitUrl = "wss://${domain}/livekit/sfu";
          inherit keyFile;
        };

        coturn = rec {
          enable = true;
          listening-port = 4004;
          tls-listening-port = 40004;
          no-cli = true;
          no-tcp-relay = true;
          min-port = 50000;
          max-port = 50100;
          use-auth-secret = true;
          static-auth-secret-file = config.sops.secrets."coturn/secret".path;
          realm = "turn.${domain}";
          # cert = "${config.security.acme.certs.${realm}.directory}/full.pem";
          # pkey = "${config.security.acme.certs.${realm}.directory}/key.pem";
          extraConfig = ''
            # for debugging
            verbose
            # ban private IP ranges
            no-multicast-peers
            denied-peer-ip=0.0.0.0-0.255.255.255
            denied-peer-ip=10.0.0.0-10.255.255.255
            denied-peer-ip=100.64.0.0-100.127.255.255
            denied-peer-ip=127.0.0.0-127.255.255.255
            denied-peer-ip=169.254.0.0-169.254.255.255
            denied-peer-ip=172.16.0.0-172.31.255.255
            denied-peer-ip=192.0.0.0-192.0.0.255
            denied-peer-ip=192.0.2.0-192.0.2.255
            denied-peer-ip=192.88.99.0-192.88.99.255
            denied-peer-ip=192.168.0.0-192.168.255.255
            denied-peer-ip=198.18.0.0-198.19.255.255
            denied-peer-ip=198.51.100.0-198.51.100.255
            denied-peer-ip=203.0.113.0-203.0.113.255
            denied-peer-ip=240.0.0.0-255.255.255.255
            denied-peer-ip=::1
            denied-peer-ip=64:ff9b::-64:ff9b::ffff:ffff
            denied-peer-ip=::ffff:0.0.0.0-::ffff:255.255.255.255
            denied-peer-ip=100::-100::ffff:ffff:ffff:ffff
            denied-peer-ip=2001::-2001:1ff:ffff:ffff:ffff:ffff:ffff:ffff
            denied-peer-ip=2002::-2002:ffff:ffff:ffff:ffff:ffff:ffff:ffff
            denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
            denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff
          '';
        };
      }
    ];

    networking.firewall = {
      allowedTCPPortRanges = [];
      allowedTCPPorts = [
        # Synapse
        port

        # coTURN ports
        config.services.coturn.listening-port
        config.services.coturn.alt-listening-port
        config.services.coturn.tls-listening-port
        config.services.coturn.alt-tls-listening-port
      ];
      allowedUDPPortRanges = with config.services.coturn;
        lib.singleton {
          from = min-port;
          to = max-port;
        };
      allowedUDPPorts = [
        # coTURN ports
        config.services.coturn.listening-port
        config.services.coturn.alt-listening-port
      ];
    };

    systemd = {
      services.livekit-key = {
        before = ["lk-jwt-service.service" "livekit.service"];
        wantedBy = ["multi-user.target"];
        path = with pkgs; [livekit coreutils gawk];
        script = ''
          echo "Key missing, generating key"
          echo "lk-jwt-service: $(livekit-server generate-keys | tail -1 | awk '{print $3}')" > "${keyFile}"
        '';
        serviceConfig.Type = "oneshot";
        unitConfig.ConditionPathExists = "!${keyFile}";
      };
      services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = "${domain}";
    };

    sops = {
      secrets = {
        "synapse/oidc_id" = {
          restartUnits = ["synapse-matrix.service"];
        };
        "synapse/oidc_secret" = {
          restartUnits = ["synapse-matrix.service"];
        };
        "synapse/shared_secret" = {
          restartUnits = ["synapse-matrix.service"];
        };
        "coturn/secret" = {
          owner = config.systemd.services.coturn.serviceConfig.User;
          group = config.systemd.services.coturn.serviceConfig.Group;
          restartUnits = ["coturn.service"];
        };
      };

      templates = {
        "synapse.yaml" = {
          owner = "matrix-synapse";
          content = ''
            registration_shared_secret: ${config.sops.placeholder."synapse/shared_secret"}
          '';
          restartUnits = ["matrix-synapse.service"];
        };
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
                  - email
                  - offline_access
                client_id: '${config.sops.placeholder."synapse/oidc_id"}'
                client_secret: '${config.sops.placeholder."synapse/oidc_secret"}'
                backchannel_logout_enabled: true
                user_profile_method: userinfo_endpoint
                allow_existing_users: true
                enable_registration: true
                user_mapping_provider:
                  config:
                    localpart_template: "{{ user.preferred_username }}"
                    display_name_template: "{{ user.name }}"
                    email_template: "{{ user.email }}"
          '';
          restartUnits = ["matrix-synapse.service"];
        };
      };
    };
  };
}
