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

    interface = {lib, ...}: let
      inherit (lib) mkOption types toSentenceCase literalExpression;
    in {
      options = {
        driver = mkOption {
          type = types.enum ["zitadel"];
          default = "zitadel";
        };

        database = mkOption {
          type = types.anything;
        };

        port = mkOption {
          type = types.port;
          default = 9092;
        };

        organization = mkOption {
          type = types.attrsOf (types.submodule ({ name, ... }: {
            options =
            let
              org = name;
            in
            {
              isDefault = mkOption {
                type = types.bool;
                default = false;
                example = "true";
                description = ''
                  True sets the '${org}' org as default org for the instance. Only one org can be default org.
                  Nothing happens if you set it to false until you set another org as default org.
                '';
              };

              project = mkOption {
                default = {};
                type = types.attrsOf (types.submodule {
                  options = {
                    hasProjectCheck = mkOption {
                      type = types.bool;
                      default = false;
                      example = "true";
                      description = ''
                        ZITADEL checks if the org of the user has permission to this project.
                      '';
                    };

                    privateLabelingSetting = mkOption {
                      type = types.nullOr (types.enum [ "unspecified" "enforceProjectResourceOwnerPolicy" "allowLoginUserResourceOwnerPolicy" ]);
                      default = null;
                      example = "enforceProjectResourceOwnerPolicy";
                      description = ''
                        Defines from where the private labeling should be triggered,

                        supported values:
                          - unspecified
                          - enforceProjectResourceOwnerPolicy
                          - allowLoginUserResourceOwnerPolicy
                      '';
                    };

                    projectRoleAssertion = mkOption {
                      type = types.bool;
                      default = false;
                      example = "true";
                      description = ''
                        Describes if roles of user should be added in token.
                      '';
                    };

                    projectRoleCheck = mkOption {
                      type = types.bool;
                      default = false;
                      example = "true";
                      description = ''
                        ZITADEL checks if the user has at least one on this project.
                      '';
                    };

                    role = mkOption {
                      default = {};
                      type = types.attrsOf (types.submodule ({ name, ... }: {
                        options =
                        let
                          roleName = name;
                        in
                        {
                          displayName = mkOption {
                            type = types.str;
                            default = toSentenceCase name;
                            example = "RoleName";
                            description = ''
                              Name used for project role.
                            '';
                          };

                          group = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            example = "some_group";
                            description = ''
                              Group used for project role.
                            '';
                          };
                        };
                      }));
                    };

                    assign = mkOption {
                      default = {};
                      type = types.attrsOf (types.listOf types.str);
                    };

                    application = mkOption {
                      default = {};
                      type = types.attrsOf (types.submodule {
                        options = {
                          redirectUris = mkOption {
                            type = types.nonEmptyListOf types.str;
                            example = ''
                              [ "https://example.com/redirect/url" ]
                            '';
                            description = ''
                              .
                            '';
                          };

                          grantTypes = mkOption {
                            type = types.nonEmptyListOf (types.enum [ "authorizationCode" "implicit" "refreshToken" "deviceCode" "tokenExchange" ]);
                            example = ''
                              [ "authorizationCode" ]
                            '';
                            description = ''
                              .
                            '';
                          };

                          responseTypes = mkOption {
                            type = types.nonEmptyListOf (types.enum [ "code" "idToken" "idTokenToken" ]);
                            example = ''
                              [ "code" ]
                            '';
                            description = ''
                              .
                            '';
                          };

                          exportMap =
                            let
                              strOpt = mkOption { type = types.nullOr types.str; default = null; };
                            in
                            mkOption {
                              type = types.submodule { options = { client_id = strOpt; client_secret = strOpt; }; };
                              default = {};
                              example = literalExpression ''
                                {
                                  client_id = "SSO_CLIENT_ID";
                                  client_secret = "SSO_CLIENT_SECRET";
                                }
                              '';
                              description = ''
                                Remap the outputted variables to another key.
                              '';
                            };
                        };
                      });
                    };
                  };
                });
              };

              user = mkOption {
                default = {};
                type = types.attrsOf (types.submodule ({ name, ... }: {
                  options =
                  let
                    username = name;
                  in
                  {
                    email = mkOption {
                      type = types.str;
                      example = "someone@some.domain";
                      description = ''
                        Username.
                      '';
                    };

                    userName = mkOption {
                      type = types.nullOr types.str;
                      default = username;
                      example = "some_user_name";
                      description = ''
                        Username. Default value is the key of the config object you created, you can overwrite that by setting this option
                      '';
                    };

                    firstName = mkOption {
                      type = types.str;
                      example = "John";
                      description = ''
                        First name of the user.
                      '';
                    };

                    lastName = mkOption {
                      type = types.str;
                      example = "Doe";
                      description = ''
                        Last name of the user.
                      '';
                    };

                    roles = mkOption {
                      type = types.listOf types.str;
                      default = [];
                      example = "[ \"ORG_OWNER\" ]";
                      description = ''
                        List of roles granted to organisation.
                      '';
                    };

                    instanceRoles = mkOption {
                      type = types.listOf types.str;
                      default = [];
                      example = "[ \"IAM_OWNER\" ]";
                      description = ''
                        List of roles granted to instance.
                      '';
                    };
                  };
                }));
              };

              action = mkOption {
                default = {};
                type = types.attrsOf (types.submodule ({ name, ... }: {
                  options = {
                    script = mkOption {
                      type = types.str;
                      example = ''
                        (ctx, api) => {
                          api.v1.claims.setClaim('some_claim', 'some_value');
                        };
                      '';
                      description = ''
                        The script to run. This must be a function that receives 2 parameters, and returns void. During the creation of the action's script this module simly does `const {{name}} = {{script}}`.
                      '';
                    };

                    timeout = mkOption {
                      type = (types.ints.between 0 20);
                      default = 10;
                      example = "10";
                      description = ''
                        After which time the action will be terminated if not finished.
                      '';
                    };

                    allowedToFail = mkOption {
                      type = types.bool;
                      default = true;
                      example = "true";
                      description = ''
                        Allowed to fail.
                      '';
                    };
                  };
                }));
              };

              triggers = mkOption {
                default = [];
                type = types.listOf (types.submodule {
                  options = {
                    flowType = mkOption {
                      type = types.enum [ "authentication" "customiseToken" "internalAuthentication" "samlResponse" ];
                      example = "customiseToken";
                      description = ''
                        Type of the flow to which the action triggers belong.
                      '';
                    };

                    triggerType = mkOption {
                      type = types.enum [ "postAuthentication" "preCreation" "postCreation"  "preUserinfoCreation" "preAccessTokenCreation" "preSamlResponse" ];
                      example = "postAuthentication";
                      description = ''
                        Trigger type on when the actions get triggered.
                      '';
                    };

                    actions = mkOption {
                      type = types.nonEmptyListOf types.str;
                      example = ''[ "action_name" ]'';
                      description = ''
                        Names of actions to trigger
                      '';
                    };
                  };
                });
              };
            };
          }));
        };
      };
    };

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
              dependencies = ["persistence"];

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
                      Password: $(cat $in/persistence/zitadel_password)
                    Admin:
                      Password: $(cat $in/persistence/zitadel_password)
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
