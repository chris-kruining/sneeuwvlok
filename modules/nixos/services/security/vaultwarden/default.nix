{
  pkgs,
  config,
  lib,
  namespace,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption mkOption types getAttrs toUpper concatMapAttrsStringSep;

  cfg = config.${namespace}.services.security.vaultwarden;

  databaseProviderSqlite = types.submodule ({...}: {
    options = {
      type = mkOption {
        type = types.enum ["sqlite"];
      };

      file = mkOption {
        type = types.path;
        description = ''
          Path to sqlite database file.
        '';
      };
    };
  });

  databaseProviderPostgresql = types.submodule ({...}: let
    urlOptions = lib.${namespace}.options.mkUrlOptions {
      host = {
        description = ''
          Hostname of the postgresql server
        '';
      };

      port = {
        default = 5432;
        example = "5432";
        description = ''
          Port of the postgresql server
        '';
      };

      protocol = mkOption {
        default = "postgres";
        example = "postgres";
      };
    };
  in {
    options =
      {
        type = mkOption {
          type = types.enum ["postgresql"];
        };

        sslMode = mkOption {
          type = types.enum ["verify-ca" "verify-full" "require" "prefer" "allow" "disabled"];
          default = "verify-full";
          example = "verify-ca";
          description = ''
            How to verify the server's ssl

            | mode        | eavesdropping protection | MITM protection      | Statement                                                                                                                                   |
            |-------------|--------------------------|----------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
            | disable     | No                       | No                   | I don't care about security, and I don't want to pay the overhead of encryption.                                                            |
            | allow       | Maybe                    | No                   | I don't care about security, but I will pay the overhead of encryption if the server insists on it.                                         |
            | prefer      | Maybe                    | No                   | I don't care about encryption, but I wish to pay the overhead of encryption if the server supports it.                                      |
            | require     | Yes                      | No                   | I want my data to be encrypted, and I accept the overhead. I trust that the network will make sure I always connect to the server I want.   |
            | verify-ca	  | Yes                      | Depends on CA policy | I want my data encrypted, and I accept the overhead. I want to be sure that I connect to a server that I trust.                             |
            | verify-full | Yes                      | Yes                  | I want my data encrypted, and I accept the overhead. I want to be sure that I connect to a server I trust, and that it's the one I specify. |

            [Source](https://www.postgresql.org/docs/current/libpq-ssl.html#LIBPQ-SSL-SSLMODE-STATEMENTS)
          '';
        };
      }
      // (urlOptions |> getAttrs ["protocol" "host" "port"]);
  });
in {
  options.${namespace}.services.security.vaultwarden = {
    enable = mkEnableOption "enable vaultwarden";

    database = mkOption {
      type = types.oneOf [
        (types.addCheck databaseProviderSqlite (x: x ? type && x.type == "sqlite"))
        (types.addCheck databaseProviderPostgresql (x: x ? type && x.type == "postgresql"))
        null
      ];
      default = null;
      description = '''';
    };
  };

  config = mkIf cfg.enable {
    ${namespace}.services.networking.caddy.hosts = {
      "vault.kruining.eu" = ''
        encode zstd gzip

        handle_path /admin {
          respond 401 {
            close
          }
        }

        reverse_proxy http://localhost:${toString config.services.vaultwarden.config.ROCKET_PORT} {
          header_up X-Real-IP {remote_host}
        }
      '';
    };

    systemd.tmpfiles.rules = [
      "d '/var/lib/vaultwarden' 0700 vaultwarden vaultwarden - -"
    ];

    # systemd.services.vaultwarden.wants = [ "zitadelApplyTerraform.service" ];

    services = {
      vaultwarden = {
        enable = true;
        dbBackend = "postgresql";

        package = pkgs.${namespace}.vaultwarden;

        config = {
          SIGNUPS_ALLOWED = false;
          DOMAIN = "https://vault.kruining.eu";

          DATABASE_URL = "postgres://localhost:5432/vaultwarden?sslmode=disable";

          WEB_VAULT_ENABLED = true;

          SSO_ENABLED = true;
          SSO_ONLY = true;
          SSO_PKCE = true;
          SSO_AUTH_ONLY_NOT_SESSION = false;
          SSO_ROLES_ENABLED = true;
          SSO_ORGANIZATIONS_ENABLED = true;
          SSO_ORGANIZATIONS_REVOCATION = true;
          SSO_AUTHORITY = "https://auth.kruining.eu/";
          SSO_SCOPES = "email profile offline_access";

          ROCKET_ADDRESS = "::1";
          ROCKET_PORT = 8222;
          ROCKET_LOG = "critical";

          SMTP_HOST = "black-mail.nl";
          SMTP_PORT = 587;
          SMTP_SECURITY = "starttls";
          SMTP_USERNAME = "chris@kruining.eu";
          SMTP_FROM = "chris@kruining.eu";
          SMTP_FROM_NAME = "Chris' Vaultwarden";
        };

        environmentFile = [
          "/var/lib/zitadel/clients/nix_ulmo_vaultwarden"
          config.sops.templates."vaultwarden/config.env".path
        ];
      };

      postgresql = {
        enable = true;
        ensureDatabases = ["vaultwarden"];
        ensureUsers = [
          {
            name = "vaultwarden";
            ensureDBOwnership = true;
          }
        ];
      };
    };

    sops = {
      secrets = {
        "vaultwarden/email" = {
          owner = config.users.users.vaultwarden.name;
          group = config.users.users.vaultwarden.name;
          key = "email/chris_kruining_eu";
          restartUnits = ["vaultwarden.service"];
        };
      };

      templates = {
        "vaultwarden/config.env" = {
          content = ''
            SMTP_PASSWORD='${config.sops.placeholder."vaultwarden/email"}';
          '';
          owner = config.users.users.vaultwarden.name;
          group = config.users.groups.vaultwarden.name;
        };
        temp-db-output.content = let
          config =
            cfg.database
            |> (
              {type, ...} @ db:
                if type == "sqlite"
                then {inherit (db) type file;}
                else if type == "postgresql"
                then {
                  inherit (db) type;
                  url = lib.${namespace}.strings.toUrl {
                    inherit (db) protocol host port;
                    path = "vaultwarden";
                    query = {
                      sslmode = db.sslMode;
                    };
                  };
                }
                else {}
            )
            |> concatMapAttrsStringSep "\n" (n: v: "${toUpper n}=${v}");
        in ''
          # GENERATED VALUES
          ${config}
        '';
      };
    };
  };
}
