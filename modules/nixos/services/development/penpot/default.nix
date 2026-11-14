{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types concatStringsSep;

  cfg = config.${namespace}.services.development.penpot;
  zitadel = config.${namespace}.services.authentication.zitadel;
  oidc = zitadel.organization.nix.project.ulmo.application.penpot;

  publicUri = "https://${cfg.domain}";

  # Ulmo's development block of ports, 50x0 per service. The containers share the host's network, everything behind the
  # frontend listens on loopback only
  ports = {
    frontend = 5020;
    backend = 5021;
    exporter = 5022;
    mcp = 5023;
    mcpWebsocket = 5024;
    redis = 5025;
    # Nginx's stub_status, which nothing here scrapes
    nginxStatus = 5026;
    # Penpot's management socket and the endpoint that drives it for zitadel
    prepl = 5027;
    provision = 5028;
  };

  redis = "redis://127.0.0.1:${toString ports.redis}/0";

  # Zitadel's sign in action posts the user here, through caddy: actions may not call loopback
  provisionPath = "/zitadel/provision";

  flags = concatStringsSep " " [
    "enable-login-with-oidc"
    # Accounts are made by zitadel's sign in action, see provision.py. Penpot's own sign up after an oidc sign in
    # needs password sign in, which is off
    "disable-registration"
    "disable-login-with-password"
    "disable-email-verification"
    "disable-onboarding"
    "disable-telemetry"
    # Not run, the frontend would otherwise proxy to it
    "disable-admin-console"
    # The frontend proxies /mcp/stream and /mcp/ws to the MCP server
    "enable-mcp"
  ];

  image = name: "docker.io/penpotapp/${name}:${cfg.version}";

  common = {
    extraOptions = ["--network=host"];
    environment = {
      PENPOT_PUBLIC_URI = publicUri;
      PENPOT_FLAGS = flags;
      PENPOT_REDIS_URI = redis;
    };
  };
in {
  options.${namespace}.services.development.penpot = {
    enable = mkEnableOption "Penpot, design and prototyping, with its MCP server";

    version = mkOption {
      type = types.str;
      default = "2.19.1";
      description = "The tag of penpot's images, they are all released together";
    };

    domain = mkOption {
      type = types.str;
      default = "design.kruining.eu";
      description = "The domain caddy serves penpot at";
    };

    port = mkOption {
      type = types.port;
      default = ports.frontend;
      readOnly = true;
      description = ''
        The loopback port of penpot's frontend behind caddy, which also proxies the backend and the MCP server
        (`/mcp/stream` for the clients, `/mcp/ws` for the plugin)
      '';
    };

    mcpTokens = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {"chris@kruining.eu" = "penpot/mcp_token";};
      description = ''
        The MCP key of a user, by their email, as the sops secret holding it. It replaces the one penpot would hand out
        (Settings → Integrations), and MCP is switched on for them. The same secret goes to their MCP client, which
        then reaches the designs they have open in penpot. A user only exists after their first sign in, until then
        their key is skipped
      '';
    };

    roles = mkOption {
      type = types.listOf types.str;
      default = ["penpot"];
      description = ''
        The roles in zitadel's ulmo project that grant an account in penpot. A user who signs in with one of them gets
        an account, one who has none of them anymore gets theirs deactivated. Assign them in the project's `assign`
      '';
    };
  };

  config = mkIf cfg.enable {
    ${namespace}.services = {
      virtualisation.podman.enable = true;
      persistance.postgresql.enable = true;

      # Every route is behind a zitadel sign in, except the MCP endpoint, which answers anyone but only reaches the
      # designs of the user whose key it is given, and the provisioning endpoint, which wants zitadel's secret
      networking.caddy.hosts.${cfg.domain} = ''
        encode zstd gzip

        handle ${provisionPath} {
          reverse_proxy http://127.0.0.1:${toString ports.provision}
        }

        handle {
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        }
      '';

      authentication.zitadel.organization.nix = {
        project.ulmo = {
          role = lib.genAttrs cfg.roles (_: {group = "penpot";});

          application.penpot = {
            redirectUris = ["${publicUri}/api/auth/oidc/callback"];
            grantTypes = ["authorizationCode"];
            responseTypes = ["code"];
            exportMap = {
              client_id = "PENPOT_OIDC_CLIENT_ID";
              client_secret = "PENPOT_OIDC_CLIENT_SECRET";
            };
            restartUnits = ["podman-penpot-backend.service"];
          };
        };

        # Runs for every token zitadel hands out. Zitadel 2.71 doesn't say for which app, so it only goes out for users
        # with a role in the ulmo project: penpot's users always have one, others are skipped or kept up to date by the
        # endpoint. Zitadel waits for it, so the account exists by the time penpot looks for it. A failure doesn't stop
        # the sign in, penpot then refuses it
        action.penpotProvision = {
          timeout = 10;
          allowedToFail = true;
          script = ''
            (ctx, api) => {
              const roles = (ctx.v1.user.grants ? ctx.v1.user.grants.grants : [])
                .filter(grant => grant.projectId === '${"$"}{zitadel_project.nix_ulmo.id}')
                .flatMap(grant => grant.roles);

              if (roles.length === 0) {
                return;
              }

              const user = ctx.v1.getUser();

              const response = require('zitadel/http').fetch('${publicUri}${provisionPath}', {
                method: 'POST',
                headers: { Authorization: 'Bearer ${"$"}{trimspace(file("${config.sops.secrets."penpot/provision_secret".path}"))}' },
                body: {
                  email: user.human.email,
                  name: user.human.displayName,
                  roles,
                },
              });

              require('zitadel/log').log('penpot provisioning for ' + user.human.email + ': ' + response.status + ' ' + response.text());
            };
          '';
        };

        triggers = [
          {
            flowType = "customiseToken";
            triggerType = "preUserinfoCreation";
            actions = ["penpotProvision"];
          }
        ];
      };
    };

    services = {
      postgresql = {
        ensureDatabases = ["penpot"];
        ensureUsers = [
          {
            name = "penpot";
            ensureDBOwnership = true;
          }
        ];
      };

      # The backend's websocket notifications, the exporter's jobs and the MCP server's sessions
      redis.servers.penpot = {
        enable = true;
        port = ports.redis;
        bind = "127.0.0.1";
      };
    };

    # The images run as penpot (1001)
    systemd.tmpfiles.rules = ["d /var/lib/penpot/assets 0750 1001 1001 - -"];

    virtualisation.oci-containers.containers = {
      penpot-backend = lib.recursiveUpdate common {
        image = image "backend";
        volumes = ["/var/lib/penpot/assets:/opt/data/assets"];
        environmentFiles = [
          config.sops.templates."penpot/secret.env".path
          # PENPOT_OIDC_CLIENT_ID and PENPOT_OIDC_CLIENT_SECRET, written by tofu-zitadel
          "${oidc.directory}/env"
        ];
        environment = {
          # Starts the management socket, the other containers have none
          PENPOT_FLAGS = "${flags} enable-prepl-server";

          PENPOT_HTTP_SERVER_HOST = "127.0.0.1";
          PENPOT_HTTP_SERVER_PORT = toString ports.backend;

          # Postgres trusts loopback on ulmo, the password is never checked
          PENPOT_DATABASE_URI = "postgresql://127.0.0.1/penpot";
          PENPOT_DATABASE_USERNAME = "penpot";
          PENPOT_DATABASE_PASSWORD = "penpot";
          # It keeps 60 open by default, out of the 100 postgres has for every service on ulmo
          PENPOT_DATABASE_MAX_POOL_SIZE = "10";
          PENPOT_DATABASE_MIN_POOL_SIZE = "2";

          PENPOT_OBJECTS_STORAGE_BACKEND = "fs";
          PENPOT_OBJECTS_STORAGE_FS_DIRECTORY = "/opt/data/assets";

          PENPOT_OIDC_BASE_URI = "${zitadel.issuer}/";
          PENPOT_OIDC_SCOPES = "openid email profile";
          # Zitadel's id token has no email or name, penpot would read only that one when there is one
          PENPOT_OIDC_USER_INFO_SOURCE = "userinfo";
          # Zitadel's domain resolves to ulmo itself here, which penpot's ssrf protection refuses unless it is allowed
          PENPOT_SSRF_ALLOWED_HOSTS = zitadel.domain;

          # The management socket provision.py drives. It has no authentication, loopback keeps it to ulmo
          PENPOT_PREPL_HOST = "127.0.0.1";
          PENPOT_PREPL_PORT = toString ports.prepl;
        };
      };

      penpot-exporter = lib.recursiveUpdate common {
        image = image "exporter";
        dependsOn = ["penpot-backend"];
        environmentFiles = [config.sops.templates."penpot/secret.env".path];
        environment = {
          # It listens on every interface whatever its host is set to, the firewall keeps it in
          PENPOT_HTTP_SERVER_PORT = toString ports.exporter;
          # The exporter renders through the frontend
          PENPOT_INTERNAL_URI = "http://127.0.0.1:${toString cfg.port}";
        };
      };

      # Multi-user: every client brings its own token (`userToken` or a bearer header), the plugin in the browser connects
      # with the same token, and only then can the client touch that user's open design
      penpot-mcp = lib.recursiveUpdate common {
        image = image "mcp";
        environment = {
          PENPOT_MCP_SERVER_HOST = "127.0.0.1";
          PENPOT_MCP_SERVER_PORT = toString ports.mcp;
          PENPOT_MCP_WEBSOCKET_PORT = toString ports.mcpWebsocket;
          PENPOT_MCP_REDIS_URI = redis;
        };
      };

      penpot-frontend = lib.recursiveUpdate common {
        image = image "frontend";
        dependsOn = ["penpot-backend" "penpot-exporter" "penpot-mcp"];
        volumes = ["/var/lib/penpot/assets:/opt/data/assets"];
        environment = {
          PENPOT_BACKEND_URI = "http://127.0.0.1:${toString ports.backend}";
          PENPOT_EXPORTER_URI = "http://127.0.0.1:${toString ports.exporter}";
          PENPOT_MCP_URI = "http://127.0.0.1:${toString ports.mcp}";
          PENPOT_MCP_URI_WS = "http://127.0.0.1:${toString ports.mcpWebsocket}";
          PENPOT_OIDC_NAME = "Zitadel";
          # Caddy reaches it over ipv4 loopback, there is no ipv6 listener
          PENPOT_IPV6_LISTEN_DIRECTIVE = "";
        };
        # Nginx's ports are fixed in the image (8080, and 8082 for its status) and bound to every interface, the
        # entrypoint renders its config and then runs this, which moves them to loopback before nginx starts
        cmd = [
          "/bin/bash"
          "-c"
          (concatStringsSep " " [
            "sed -i"
            "-e 's/listen 8080 /listen 127.0.0.1:${toString ports.frontend} /'"
            "-e 's/listen 8082;/listen 127.0.0.1:${toString ports.nginxStatus};/'"
            "/etc/nginx/nginx.conf"
            "&& exec nginx -g 'daemon off;'"
          ])
        ];
      };
    };

    systemd.services = {
      # The oidc credentials only exist once tofu-zitadel ran
      podman-penpot-backend = {
        after = ["postgresql.service" "redis-penpot.service" "tofu-zitadel.service"];
        requires = ["postgresql.service" "redis-penpot.service"];
      };
      podman-penpot-exporter = {
        after = ["redis-penpot.service"];
        requires = ["redis-penpot.service"];
      };
      podman-penpot-mcp = {
        after = ["redis-penpot.service"];
        requires = ["redis-penpot.service"];
      };

      # Zitadel's sign in action posts here, through caddy, see provision.py
      penpot-provision = {
        description = "Create penpot accounts for zitadel's users";
        wantedBy = ["multi-user.target"];
        after = ["podman-penpot-backend.service"];
        environment = {
          PROVISION_PORT = toString ports.provision;
          PREPL_PORT = toString ports.prepl;
          PROVISION_ROLES = builtins.toJSON cfg.roles;
        };
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.python3} ${./provision.py}";
          DynamicUser = true;
          LoadCredential = ["secret:${config.sops.secrets."penpot/provision_secret".path}"];
          Restart = "on-failure";
        };
      };

      # Penpot's MCP server doesn't check a key, it pairs the client with the plugin in the browser that connects with
      # the same one. The plugin takes the user's `mcp` access token, so writing ours there is all it takes. Again every
      # few minutes: users appear at their first sign in, and a key made in penpot's settings would replace ours
      penpot-mcp-tokens = mkIf (cfg.mcpTokens != {}) {
        description = "Set the MCP keys of penpot's users";
        after = ["postgresql.service" "podman-penpot-backend.service"];
        requires = ["postgresql.service"];
        path = [config.services.postgresql.package];
        serviceConfig = {
          Type = "oneshot";
          User = "postgres";
          LoadCredential = lib.mapAttrsToList (email: secret: "${email}:${config.sops.secrets.${secret}.path}") cfg.mcpTokens;
        };
        script = concatStringsSep "\n" (lib.mapAttrsToList (email: _: ''
            psql --quiet --no-psqlrc --dbname=penpot \
              --set=ON_ERROR_STOP=1 \
              --set=email=${lib.escapeShellArg email} \
              --set=token="$(cat "$CREDENTIALS_DIRECTORY"/${lib.escapeShellArg email})" <<'SQL'
              -- Nothing yet before the backend's first migrations
              SELECT to_regclass('public.access_token') IS NOT NULL AS ready \gset
              \if :ready
                WITH profile AS (
                  SELECT id FROM profile WHERE email = lower(:'email') AND deleted_at IS NULL
                ), updated AS (
                  UPDATE access_token SET token = :'token', expires_at = NULL, updated_at = now()
                    FROM profile
                   WHERE access_token.profile_id = profile.id AND access_token.type = 'mcp'
                     AND access_token.token IS DISTINCT FROM :'token'
                  RETURNING access_token.id
                )
                INSERT INTO access_token (profile_id, name, token, type, perms)
                SELECT id, 'nix', :'token', 'mcp', '{}' FROM profile
                 WHERE NOT EXISTS (SELECT FROM access_token WHERE profile_id = profile.id AND type = 'mcp');

                -- Its props are transit, a keyword key is written as "~:<name>"
                UPDATE profile SET props = coalesce(props, '{}'::jsonb) || '{"~:mcp-enabled": true}'::jsonb
                 WHERE email = lower(:'email') AND deleted_at IS NULL
                   AND (props->'~:mcp-enabled') IS DISTINCT FROM 'true'::jsonb;
              \endif
            SQL
          '')
          cfg.mcpTokens);
      };
    };

    systemd.timers.penpot-mcp-tokens = mkIf (cfg.mcpTokens != {}) {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
      };
    };


    sops = {
      # Generated with `just vars generate ulmo`, see script/penpot/secret_key
      secrets =
        {
          "penpot/secret_key" = {};

          # Zitadel's action reads it through tofu, the endpoint through LoadCredential
          "penpot/provision_secret" = {
            owner = "zitadel";
            restartUnits = ["tofu-zitadel.service" "penpot-provision.service"];
          };
        }
        // lib.genAttrs (lib.unique (lib.attrValues cfg.mcpTokens)) (_: {
          restartUnits = ["penpot-mcp-tokens.service"];
        });

      templates."penpot/secret.env" = {
        restartUnits = ["podman-penpot-backend.service" "podman-penpot-exporter.service"];
        content = ''
          PENPOT_SECRET_KEY=${config.sops.placeholder."penpot/secret_key"}
        '';
      };
    };
  };
}
