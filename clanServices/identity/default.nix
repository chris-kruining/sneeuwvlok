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
    name = "arda/identity";
    description = ''
    '';
    readme = readFile ./README.md;
    exports = {
      inputs = ["persistence"];
      out = ["gateway" "persistence"];
    };
  };

  roles.default = {
    description = '''';

    interface = import ./interface.nix

    perInstance = {
      mkExports,
      settings,
      machine,
      instanceName,
      ...
    }: {
      exports = mkExports (mkMerge [
        {
          gateway.services.identity = {endpoint.port = settings.port;};
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
        zLib = import ./lib.nix (args // {inherit settings ardaLib;});
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
                  description = "password to email for zitadel's smpt connection";
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

                ExternalDomain = "auth.kruining.eu";
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
