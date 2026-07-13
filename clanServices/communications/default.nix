{lib, ...}: let
  inherit (builtins) toJSON toString;
  inherit (lib) mkMerge;

  bridgeNames = ["mautrix-signal" "mautrix-telegram" "mautrix-whatsapp" "arrtrix"];

  enabledBridges = matrix:
    matrix.bridges
    |> lib.filterAttrs (_: bridge: bridge.enable);

  bridgeAdmins = matrix:
    matrix.adminUsers
    |> lib.map (user: {
      name = user;
      value = "admin";
    })
    |> lib.listToAttrs;

  wellKnownClient = matrix:
    {
      "m.homeserver".base_url = "https://${matrix.serverDomain}";
      "m.identity_server".base_url = "https://auth.${matrix.domain}";
    }
    // lib.optionalAttrs matrix.livekit.enable {
      "org.matrix.msc3575.proxy".url = "https://${matrix.domain}";
      "org.matrix.msc4143.rtc_foci" = [
        {
          type = "livekit";
          livekit_service_url = "https://${matrix.domain}/livekit/jwt";
        }
      ];
    };

  wellKnownServer = matrix: {
    "m.server" = "${matrix.serverDomain}:443";
  };

  mkMautrix = matrix: bridge: {
    services.${bridge} = mkMerge [
      {
        enable = true;
        registerToSynapse = true;

        settings = {
          appservice.provisioning.enabled = false;

          homeserver = {
            domain = matrix.domain;
            address = "http://[::1]:${toString matrix.port}";
          };

          bridge.permissions = bridgeAdmins matrix;
        };
      }
      {
        mautrix-signal.settings = {
          use_contact_avatars = true;
          extev_polls = true;
        };
        mautrix-telegram = {};
        mautrix-whatsapp.settings = {
          send_presence_on_typing = true;
          url_previews = true;
          extev_polls = true;
        };
      }.${bridge}
    ];
  };

  mkArrtrix = matrix: config: {
    services.arrtrix = {
      enable = true;
      registerToSynapse = true;
      environmentFile = config.clan.core.vars.generators.arrtrix.files."secrets.env".path;

      settings = {
        homeserver = {
          domain = matrix.domain;
          address = "http://[::1]:${toString matrix.port}";
        };

        bridge.permissions = bridgeAdmins matrix;

        observability = {
          otlp_grpc_endpoint = "http://[::1]:9071";
          service_name = "arrtrix";
        };

        network.content = {
          movies = {
            url = "http://[::1]:${toString config.services.radarr.settings.server.port}";
            api_key = "$RADARR_APIKEY";
            root_folder_path = "/var/media/movies";
            quality_profile_id = 5;
          };
          series = {
            url = "http://[::1]:${toString config.services.sonarr.settings.server.port}";
            api_key = "$SONARR_APIKEY";
            root_folder_path = "/var/media/series";
            quality_profile_id = 5;
            language_profile_id = 1;
          };
        };
      };
    };

    clan.core.vars.generators.arrtrix = {
      dependencies = ["servarr"];
      files."secrets.env" = {
        secret = true;
        deploy = true;
        owner = "arrtrix";
        group = "arrtrix";
        restartUnits = ["arrtrix.service"];
      };
      script = ''
        radarr_api_key=$(sed -n 's/^ *radarr_api_key = "\(.*\)"$/\1/p' "$in/servarr/config.tfvars")
        sonarr_api_key=$(sed -n 's/^ *sonarr_api_key = "\(.*\)"$/\1/p' "$in/servarr/config.tfvars")

        cat << EOL > "$out/secrets.env"
        RADARR_APIKEY=$radarr_api_key
        SONARR_APIKEY=$sonarr_api_key
        EOL
      '';
    };
  };

  mkBridge = matrix: config: bridge: _: {
    arrtrix = mkArrtrix matrix config;
  }.${bridge} or (mkMautrix matrix bridge);
in {
  _class = "clan.service";
  manifest = {
    name = "communications";
    description = "Generic communications service";
    categories = ["Service" "Communication"];
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["gateway" "identity" "observability" "persistence"];
      out = ["gateway" "identity" "observability" "persistence"];
    };
  };

  roles.default = {
    description = "Matrix communications service";
    interface = import ./interface.nix;

    perInstance = {
      settings,
      mkExports,
      ...
    }: let
      matrix = settings.matrix;
      activeBridges = enabledBridges matrix;
    in {
      exports = mkExports {
        persistence.databases = [matrix.database];
        gateway.services.matrix = {
          endpoint.port = matrix.port;
          routes.default.host = matrix.serverDomain;
        };
        gateway.routes.matrixWellKnown = {
          host = lib.concatStringsSep ", " ([matrix.domain] ++ matrix.extraWellKnownDomains);
          endpoint.port = matrix.port;
          extraConfig = ''
            header /.well-known/matrix/* Content-Type application/json
            header /.well-known/matrix/* Access-Control-Allow-Origin *
            respond /.well-known/matrix/server `${toJSON (wellKnownServer matrix)}`
            respond /.well-known/matrix/client `${toJSON (wellKnownClient matrix)}`
          '';
        };
        identity.applications.matrix = lib.mkIf (settings.identity.provider != null) {
          provider = settings.identity.provider;
          redirectUris = ["https://${matrix.serverDomain}/_synapse/client/oidc/callback"];
          scopes = ["openid" "profile" "email" "offline_access"];
        };
        observability.metrics.matrix.targets = [
          {port = matrix.port;}
        ];
        observability.traces.matrix.protocol = "otlp-grpc";
      };

      nixosModule = {
        config,
        lib,
        pkgs,
        ...
      }: let
        turnSecretFile =
          if matrix.turn.secretFile != null
          then matrix.turn.secretFile
          else config.clan.core.vars.generators.matrix-turn-secret.files.secret.path;

        turnRealm =
          if matrix.turn.realm != null
          then matrix.turn.realm
          else "turn.${matrix.domain}";

      in {
        config = lib.mkIf (settings.driver == "matrix") (mkMerge ([
          {
            assertions = [
              {
                assertion = activeBridges |> lib.attrNames |> lib.all (name: lib.elem name bridgeNames);
                message = "Unsupported Matrix bridges: ${activeBridges |> lib.attrNames |> lib.subtractLists bridgeNames |> lib.concatStringsSep ", "}";
              }
            ];

            services = {
              matrix-synapse = {
                enable = true;
                extras = lib.optional (settings.identity.provider != null) "oidc";
                settings = {
                  server_name = matrix.domain;
                  public_baseurl = "https://${matrix.serverDomain}";
                  enable_metrics = true;
                  url_preview_enabled = true;
                  presence.enabled = true;
                  enable_registration = false;
                  enable_registration_without_verification = false;
                  password_config.enabled = true;
                  backchannel_logout_enabled = settings.identity.provider != null;
                  max_event_delay_duration = lib.mkIf matrix.livekit.enable "24h";
                  rc_message = lib.mkIf matrix.livekit.enable {
                    per_second = 0.5;
                    burst_count = 30;
                  };
                  rc_delayed_event_mgmt = lib.mkIf matrix.livekit.enable {
                    per_second = 1;
                    burst_count = 20;
                  };
                  turn_uris = lib.mkIf matrix.turn.enable [
                    "turn:${turnRealm}:${toString matrix.turn.port}?transport=udp"
                    "turn:${turnRealm}:${toString matrix.turn.port}?transport=tcp"
                  ];
                  experimental_features = {
                    msc2965_enabled = true;
                    msc3266_enabled = true;
                    msc4222_enabled = true;
                  };
                  database = {
                    name = "psycopg2";
                    args = {
                      database = matrix.database;
                      user = matrix.database;
                    };
                  };
                  listeners = [
                    {
                      bind_addresses = ["::"];
                      port = matrix.port;
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

              livekit = lib.mkIf matrix.livekit.enable {
                enable = true;
                openFirewall = true;
                keyFile = matrix.livekit.keyFile;
                settings = {
                  port = matrix.livekit.port;
                  room.auto_create = false;
                };
              };

              lk-jwt-service = lib.mkIf matrix.livekit.enable {
                enable = true;
                port = matrix.livekit.jwtPort;
                livekitUrl = "wss://${matrix.domain}/livekit/sfu";
                keyFile = matrix.livekit.keyFile;
              };

              coturn = lib.mkIf matrix.turn.enable {
                enable = true;
                listening-port = matrix.turn.port;
                no-cli = true;
                no-tcp-relay = true;
                use-auth-secret = true;
                static-auth-secret-file = turnSecretFile;
                realm = turnRealm;
                extraConfig = ''
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
            };

            clan.core.vars.generators.matrix-turn-secret = lib.mkIf (matrix.turn.enable && matrix.turn.secretFile == null) {
              files.secret = {
                owner = config.systemd.services.coturn.serviceConfig.User;
                group = config.systemd.services.coturn.serviceConfig.Group;
                mode = "0440";
                restartUnits = ["coturn.service"];
              };
              runtimeInputs = [pkgs.openssl];
              script = ''
                openssl rand -base64 32 > "$out/secret"
              '';
            };

            networking.firewall = {
              allowedTCPPorts =
                [matrix.port]
                ++ lib.optionals matrix.turn.enable [config.services.coturn.listening-port config.services.coturn.tls-listening-port];
              allowedUDPPorts = lib.optionals matrix.turn.enable [
                config.services.coturn.listening-port
                config.services.coturn.alt-listening-port
              ];
              allowedUDPPortRanges = lib.optionals matrix.turn.enable [
                {
                  from = config.services.coturn.min-port;
                  to = config.services.coturn.max-port;
                }
              ];
            };

            systemd = {
              services.livekit-key = lib.mkIf matrix.livekit.enable {
                before = ["lk-jwt-service.service" "livekit.service"];
                wantedBy = ["multi-user.target"];
                path = with pkgs; [livekit coreutils gawk];
                script = ''
                  echo "Key missing, generating key"
                  echo "lk-jwt-service: $(livekit-server generate-keys | tail -1 | awk '{print $3}')" > "${matrix.livekit.keyFile}"
                '';
                serviceConfig.Type = "oneshot";
                unitConfig.ConditionPathExists = "!${matrix.livekit.keyFile}";
              };

              services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = lib.mkIf matrix.livekit.enable matrix.domain;
            };
          }
        ]
        ++ (activeBridges |> lib.mapAttrsToList (mkBridge matrix config))));
      };
    };
  };
}
