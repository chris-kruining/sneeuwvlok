{lib, ...}:
let
  inherit (lib) mkOption types toSentenceCase literalExpression;
in
{
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
}
