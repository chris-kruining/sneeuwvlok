{
  lib,
  clanLib,
  exports,
  ...
}: let
  inherit (builtins) toString readFile;
  inherit (lib) mkMerge mkIf;
in {
  _class = "clan.service";
  manifest = {
    name = "identity";
    description = ''
    '';
    readme = readFile ./README.md;
    exports = {
      inputs = ["persistence"];
      out = ["gateway" "identity" "persistence"];
    };
  };

  roles.default = {
    description = '''';

    interface = import ./interface.nix;

    perInstance = {
      mkExports,
      settings,
      machine,
      instanceName,
      ...
    }: let
      normalizeApplication = name: application:
        application
        // lib.optionalAttrs (application.redirectUris == [] && application.origin != null && application.callbackPath != null) {
          redirectUris = ["${application.origin}${application.callbackPath}"];
        };

      normalizeApplications = applications:
        applications
        |> lib.mapAttrs normalizeApplication;

      exportedApplications =
        exports
        |> clanLib.selectExports (_scope: true)
        |> lib.mapAttrsToList (_: value: value.identity.applications or {})
        |> lib.foldl' (applications: exported: applications // exported) {};

      effectiveOrganizations =
        settings.organization
        |> lib.mapAttrs (_orgName: org:
          org
          // {
            project =
              org.project
              |> lib.mapAttrs (_projectName: project:
                project
                // {
                  application =
                    (project.application |> normalizeApplications)
                    // (project.consumers
                      |> lib.map (name: {
                        inherit name;
                        value = normalizeApplication name exportedApplications.${name};
                      })
                      |> lib.listToAttrs);
                });
          });

      effectiveSettings = settings // {organization = effectiveOrganizations;};
    in {
      exports = mkExports (mkMerge [
        {
          gateway.services.identity = {
            endpoint = {
              protocol = "h2c";
              host = "[::1]";
              port = settings.port;
            };
            routes.default.host = settings.externalDomain;
          };
          identity.provider = {
            name = settings.driver;
            origin =
              if settings.origin != null
              then settings.origin
              else "https://${settings.externalDomain}";
          };
        }
        (mkIf (settings.driver == "zitadel") {
          gateway.functions.auth = {
            body = ''
              forward_auth h2c://[::1]:${toString settings.port} {
                uri /api/authz/forward-auth
                copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
              }
            '';
          };

          persistence.databases = ["zitadel"];
        })
      ]);

      nixosModule = args@{
        lib,
        pkgs,
        config,
        ...
      }: let
        vars = config.clan.core.vars.generators.zitadel.files;
        users = config.clan.core.vars.generators.zitadel_users.files.users.path;
        email_password = config.clan.core.vars.generators.zitadel_email_password.files.password.path;

        ardaLib = import ../../lib/strings.nix args;
        zLib = import ./lib.nix (args // {
          settings = effectiveSettings;
          inherit ardaLib;
        });
      in {
        config = mkMerge [
          (mkIf (settings.driver == "zitadel") ({
            clan.core.vars.generators.zitadel = {
              dependencies = ["postgresql"];

              files = {
                masterKey = {
                  deploy = true;
                  owner = "zitadel";
                  group = "zitadel";
                  restartUnits = ["zitadel.service"];
                };

                settings = {
                  deploy = true;
                  owner = "zitadel";
                  group = "zitadel";
                  restartUnits = ["zitadel.service"];
                };

                infraPrivateKey = {
                  deploy = true;
                  owner = "zitadel";
                  group = "zitadel";
                  restartUnits = ["zitadel.service"];
                };

                infraPublicKey = {
                  deploy = true;
                  owner = "zitadel";
                  group = "zitadel";
                  restartUnits = ["zitadel.service"];
                };
              };

              runtimeInputs = with pkgs; [pwgen openssl_3_5];
              script = ''
                pwgen -s 32 1 > $out/masterKey

                openssl genrsa -traditional -out $out/infraPrivateKey 2048
                openssl rsa -pubout -in $out/infraPrivateKey -out $out/infraPublicKey

                cat << EOL > $out/settings
                Database:
                  postgres:
                    User:
                      Password: $(cat $in/postgresql/zitadel_password)
                    Admin:
                      Password: $(cat $in/postgresql/zitadel_password)
                EOL
              '';
            };

            clan.core.vars.generators.zitadel_users = {
              files = {
                users = {
                  deploy = true;
                  owner = "zitadel";
                  group = "zitadel";
                  restartUnits = ["infra-zitadel.service"];
                };
              };

              script = ''
                echo "{}" > $out/users
              '';
            };

            clan.core.vars.generators.zitadel_email_password = {
              prompts = {
                password = {
                  description = "password to email for zitadel's SMTP connection";
                  type = "hidden";
                  persist = true;
                };
              };

              files = {
                password = {
                  deploy = true;
                  owner = "zitadel";
                  group = "zitadel";
                  restartUnits = ["infra-zitadel.service"];
                };
              };

              script = ''
                cat $prompts/password > $out/password
              '';
            };

            environment.systemPackages = with pkgs; [
              zitadel
            ];

            services.zitadel = {
              enable = true;
              masterKeyFile = vars.masterKey.path;

              tlsMode = "external";

              extraSettingsPaths = [
                vars.settings.path
              ];

              settings = {
                Port = settings.port;

                ExternalDomain = settings.externalDomain;
                ExternalPort = 443;
                ExternalSecure = true;

                Metrics.Type = "otel";
                Tracing.Type = "otel";
                Telemetry.Enabled = true;

                SystemDefaults = {
                  PasswordHasher.Hasher.Algorithm = "argon2id";
                  SecretHasher.Hasher.Algorithm = "argon2id";
                };

                Database.postgres = {
                  Host = settings.database.host;
                  Port = settings.database.port;
                  Database = "zitadel";
                  User = {
                    Username = "zitadel";
                  };
                  Admin = {
                    Username = "zitadel";
                  };
                };

                SystemAPIUsers = {
                  infra = {
                    Path = vars.infraPublicKey.path;
                    Memberships = [
                      { MemberType = "System"; Roles = [ "SYSTEM_OWNER" "IAM_OWNER" "ORG_OWNER" ]; }
                    ];
                  };
                };
              };
            };
          } // (zLib.createInfra { inherit users email_password; key_file = vars.infraPrivateKey.path; })))
        ];
      };
    };
  };
}
