{lib, ...}: {
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
      }: {
        config = lib.mkIf (settings.driver == "matrix") {
          services = {
            matrix-synapse = {
              enable = true;
              extras = lib.optional (settings.identity.provider != null) "oidc";
              settings = {
                server_name = matrix.domain;
                public_baseurl = "https://${matrix.serverDomain}";
                enable_metrics = true;
                url_preview_enabled = true;
                enable_registration = false;
                enable_registration_without_verification = false;
                password_config.enabled = true;
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
              static-auth-secret-file = matrix.turn.secretFile;
              realm =
                if matrix.turn.realm != null
                then matrix.turn.realm
                else "turn.${matrix.domain}";
            };
          };

          networking.firewall.allowedTCPPorts =
            [matrix.port]
            ++ lib.optionals matrix.turn.enable [config.services.coturn.listening-port config.services.coturn.tls-listening-port];
        };
      };
    };
  };
}
