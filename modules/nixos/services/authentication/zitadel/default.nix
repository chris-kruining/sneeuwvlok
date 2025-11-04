{ config, lib, pkgs, namespace, system, inputs, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption types toUpper toSentenceCase nameValuePair mapAttrs' concatMapAttrs filterAttrsRecursive listToAttrs imap0 head drop length;
  inherit (lib.${namespace}.strings) toSnakeCase;

  cfg = config.${namespace}.services.authentication.zitadel;

  database = "zitadel";
in
{
  options.${namespace}.services.authentication.zitadel = {
    enable = mkEnableOption "Zitadel";

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
              True sets the org as default org for the instance. Only one org can be default org. 
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

  config = let
    _refTypeMap = {
      org = { type = "org"; };
      project = { type = "project"; };
      user = { type = "user"; tfType = "human_user"; };
    };

    mapRef' = { type, tfType ? type }: name: { "${type}Id" = "\${ resource.zitadel_${tfType}.${toSnakeCase name}.id }"; };
    mapRef = type: name: mapRef' (_refTypeMap.${type}) name;
    mapEnum = prefix: value: "${prefix}_${value |> toSnakeCase |> toUpper}";

    mapValue = type: value: ({
      appType = mapEnum "OIDC_APP_TYPE" value;
      grantTypes = map (t: mapEnum "OIDC_GRANT_TYPE" t) value;
      responseTypes = map (t: mapEnum "OIDC_RESPONSE_TYPE" t) value;
      authMethodType = mapEnum "OIDC_AUTH_METHOD_TYPE" value;

      flowType = mapEnum "FLOW_TYPE" value;
      triggerType = mapEnum "TRIGGER_TYPE" value;
      accessTokenType = mapEnum "OIDC_TOKEN_TYPE" value;
    }."${type}" or value);

    toResource = name: value: nameValuePair 
      (toSnakeCase name)
      (lib.mapAttrs' (k: v: nameValuePair (toSnakeCase k) (mapValue k v)) value);

    withRef = type: name: attrs: attrs // (mapRef type name);

    select = keys: callback: set:
      if (length keys) == 0 then 
        mapAttrs' callback set
      else let key = head keys; in
        concatMapAttrs (k: v: select (drop 1 keys) (callback k) (v.${key} or {})) set
    ;

    config' = config;

    # this is a nix package, the generated json file to be exact
    terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
      inherit system;

      modules = [
        ({ config, lib, ... }: {
          config = {
            terraform.required_providers.zitadel = {
              source = "zitadel/zitadel";
              version = "2.2.0";
            };

            provider.zitadel = {
              domain = "auth.kruining.eu";
              insecure = "false";
              jwt_profile_file = "/var/lib/zitadel/machine-key.json";
            };

            resource = {
              # Organizations
              zitadel_org = cfg.organization |> select [] (name: { isDefault, ... }: 
                { inherit name isDefault; }
                |> toResource name
              );

              # Projects per organization
              zitadel_project = cfg.organization |> select [ "project" ] (org: name: { hasProjectCheck, privateLabelingSetting, projectRoleAssertion, projectRoleCheck, ... }: 
                {
                  inherit name hasProjectCheck privateLabelingSetting projectRoleAssertion projectRoleCheck;
                }
                |> withRef "org" org
                |> toResource "${org}_${name}"
              );

              # Each OIDC app per project
              zitadel_application_oidc = cfg.organization |> select [ "project" "application" ] (org: project: name: { redirectUris, grantTypes, responseTypes, ...}: 
                {
                  inherit name redirectUris grantTypes responseTypes;

                  accessTokenRoleAssertion = true;
                  idTokenRoleAssertion = true;
                  accessTokenType = "JWT";
                }
                |> withRef "org" org 
                |> withRef "project" "${org}_${project}" 
                |> toResource "${org}_${project}_${name}"
              );

              # Each project role
              zitadel_project_role = cfg.organization |> select [ "project" "role" ] (org: project: name: value: 
                { inherit (value) displayName group; roleKey = name; }
                |> withRef "org" org 
                |> withRef "project" "${org}_${project}" 
                |> toResource "${org}_${project}_${name}"
              );

              # Each project role assignment
              zitadel_user_grant = cfg.organization |> select [ "project" "assign" ] (org: project: user: roles:
                { roleKeys = roles; }
                |> withRef "org" org 
                |> withRef "project" "${org}_${project}" 
                |> withRef "user" "${org}_${user}" 
                |> toResource "${org}_${project}_${user}"
              );

              # Users
              zitadel_human_user = cfg.organization |> select [ "user" ] (org: name: { email, userName, firstName, lastName, ... }: 
                {
                  inherit email userName firstName lastName;

                  isEmailVerified = true;
                } 
                |> withRef "org" org
                |> toResource "${org}_${name}"
              );

              # Global user roles
              zitadel_instance_member = 
                cfg.organization 
                |> filterAttrsRecursive (n: v: !(v ? "instanceRoles" && (length v.instanceRoles) == 0))
                |> select [ "user" ] (org: name: { instanceRoles, ... }: 
                  { roles = instanceRoles; } 
                  |> withRef "user" "${org}_${name}"
                  |> toResource "${org}_${name}"
                );

              # Organazation specific roles
              zitadel_org_member = 
                cfg.organization
                |> filterAttrsRecursive (n: v: !(v ? "roles" && (length v.roles) == 0))
                |> select [ "user" ] (org: name: { roles, ... }: 
                  { inherit roles; }
                  |> withRef "org" org
                  |> withRef "user" "${org}_${name}"
                  |> toResource "${org}_${name}"
                );

              # Organazation's actions
              zitadel_action = cfg.organization |> select [ "action" ] (org: name: { timeout, allowedToFail, script, ...}: 
                { 
                  inherit allowedToFail name; 
                  timeout = "${toString timeout}s";
                  script = "const ${name} = ${script}";
                }
                |> withRef "org" org
                |> toResource "${org}_${name}"
              );

              # Organazation's action assignments
              zitadel_trigger_actions = 
                cfg.organization
                |> concatMapAttrs (org: { triggers, ... }:
                  triggers
                  |> imap0 (i: { flowType, triggerType, actions, ... }: (let name = "trigger_${toString i}"; in
                    {
                      inherit flowType triggerType; 

                      actionIds = 
                        actions 
                        |> map (action: (lib.tfRef "zitadel_action.${org}_${toSnakeCase action}.id"));
                    } 
                    |> withRef "org" org 
                    |> toResource "${org}_${name}" 
                  ))
                  |> listToAttrs
                );

              # SMTP config
              zitadel_smtp_config.default = {
                sender_address = "chris@kruining.eu";
                sender_name = "no-reply (Zitadel)";
                tls = true;
                host = "black-mail.nl:587";
                user = "chris@kruining.eu";
                password = lib.tfRef "file(\"${config'.sops.secrets."zitadel/email".path}\")";
                set_active = true;
              };

              # Client credentials per app
              local_sensitive_file = cfg.organization |> select [ "project" "application" ] (org: project: name: value: 
                nameValuePair "${org}_${project}_${name}" {
                  content = ''
                    CLIENT_ID=${lib.tfRef "resource.zitadel_application_oidc.${org}_${project}_${name}.client_id"}
                    CLIENT_SECRET=${lib.tfRef "resource.zitadel_application_oidc.${org}_${project}_${name}.client_secret"}
                  '';
                  filename = "/var/lib/zitadel/clients/${org}_${project}_${name}";
                }
              );
            };
          };
        })
      ];
    };
  in 
  mkIf cfg.enable {
    ${namespace}.services.persistance.postgresql.enable = true;

    environment.systemPackages = with pkgs; [
      zitadel
    ];

    systemd.tmpfiles.rules = [
      "d /tmp/zitadelApplyTerraform 0755 zitadel zitadel -"
      "d /var/lib/zitadel/clients 0755 zitadel zitadel -"
    ];

    systemd.services.zitadelApplyTerraform = {
      description = "Zitadel terraform apply";

      wantedBy = [ "multi-user.target" ];
      wants = [ "zitadel.service" ];
      
      script = ''
        #!/usr/bin/env bash

        if [ "$(systemctl is-active zitadel)" != "active" ]; then
          echo "Zitadel is not running"
          exit 1
        fi

        # Print the path to the source for easier debugging
        echo "config location: ${terraformConfiguration}"

        # Copy infra code into workspace
        cp -f ${terraformConfiguration} config.tf.json

        # Initialize OpenTofu
        ${lib.getExe pkgs.opentofu} init

        # Run the infrastructure code
        # ${lib.getExe pkgs.opentofu} plan
        ${lib.getExe pkgs.opentofu} apply -auto-approve
      '';

      serviceConfig = {
        Type = "oneshot";
        User = "zitadel";
        Group = "zitadel";

        WorkingDirectory = "/tmp/zitadelApplyTerraform";
      };
    };

    services = {
      zitadel = {
        enable = true;
        openFirewall = true;
        masterKeyFile = config.sops.secrets."zitadel/masterKey".path;
        tlsMode = "external";
        settings = {
          Port = 9092;

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
            Host = "localhost";
            # Zitadel will report error if port is not set
            Port = 5432;
            Database = database;
            User = {
              Username = database;
              SSL.Mode = "disable";
            };
            Admin = {
              Username = "postgres";
              SSL.Mode = "disable";
            };
          };
        };
        steps = {
          FirstInstance = {
            # Not sure, this option seems to be mostly irrelevant
            InstanceName = "eu";

            MachineKeyPath = "/var/lib/zitadel/machine-key.json";
            # PatPath = "/var/lib/zitadel/machine-key.pat";
            # LoginClientPatPath = "/var/lib/zitadel/machine-key.json";

            Org = {
              Name = "kruining";
              
              Human = {
                UserName = "chris";
                FirstName = "Chris";
                LastName = "Kruining";
                Email = {
                  Address = "chris@kruining.eu";
                  Verified = true;
                };
                Password = "KaasIsAwesome1!";
              };
              
              Machine = {
                Machine = {
                  Username = "terraform-service-user";
                  Name = "Terraform";
                };
                MachineKey = { ExpirationDate = "2026-01-01T00:00:00Z"; Type = 1; };
                # Pat = { ExpirationDate = "2026-01-01T00:00:00Z"; };
              };
              
              # LoginClient.Machine = {
              #   Username = "terraform-service-user";
              #   Name = "Terraform";
              # };
            };
          };
        };
        # extraStepsPaths = [
        #   config.sops.templates."secrets.yaml".path
        # ];
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
        virtualHosts = {
          "auth.kruining.eu".extraConfig = ''
            reverse_proxy h2c://::1:9092
          '';
        };
        extraConfig = ''
          (auth) {
            forward_auth h2c://::1:9092 {
              uri /api/authz/forward-auth
              copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
            }
          }
        '';
      };
    };
      
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    # Secrets
    sops = {
      secrets = {
        "zitadel/masterKey" = {
          owner = "zitadel";
          group = "zitadel";
          restartUnits = [ "zitadel.service" ]; #EMGDB#6O$8qpGoLI1XjhUhnng1san@0
        };

        "zitadel/email" = {
          owner = "zitadel";
          group = "zitadel";
          key = "email/chris_kruining_eu";
          restartUnits = [ "zitadel.service" ];
        };
      };
    };
  };
}
