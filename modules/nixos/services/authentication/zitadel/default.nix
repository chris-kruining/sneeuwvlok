{ config, lib, pkgs, namespace, system, inputs, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption types toUpper nameValuePair;
  inherit (lib.${namespace}.strings) toSnakeCase;

  cfg = config.${namespace}.services.authentication.zitadel;

  database = "zitadel";
in
{
  options.${namespace}.services.authentication.zitadel = {
    enable = mkEnableOption "Zitadel";

    organization = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
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
        };
      });
    };
  };

  config = let
    mapRef = type: name: { "${type}Id" = "\${ resource.zitadel_${type}.${toSnakeCase name}.id }"; };
    mapEnum = prefix: value: "${prefix}_${value |> toSnakeCase |> toUpper}";

    mapValue = type: value: ({
      grantTypes = map (t: mapEnum "OIDC_GRANT_TYPE" t) value;
      responseTypes = map (t: mapEnum "OIDC_RESPONSE_TYPE" t) value;
    }."${type}" or value);

    toResource = name: value: nameValuePair 
      (toSnakeCase name)
      (lib.mapAttrs' (k: v: nameValuePair (toSnakeCase k) (mapValue k v)) value);

    withName = name: attrs: attrs // { inherit name; };
    withRef = type: name: attrs: attrs // (mapRef type name);

    # this is a nix package, the generated json file to be exact
    terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
      inherit system;

      modules = 
      let
        inherit (lib) mapAttrs' concatMapAttrs nameValuePair getAttrs getAttr hasAttr typeOf head drop length;

        select = keys: callback: set:
          if (length keys) == 0 then 
            mapAttrs' callback set
          else let key = head keys; in
            concatMapAttrs (k: v: select (drop 1 keys) (callback k) (v.${key} or {})) set;
      in
      [
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
              zitadel_org = cfg.organization |> select [] (name: value: 
                value 
                  |> getAttrs [ "isDefault" ]
                  |> withName name
                  |> toResource name
              );

              zitadel_project = cfg.organization |> select [ "project" ] (org: name: value: 
                value 
                  |> getAttrs [ "hasProjectCheck" "privateLabelingSetting" "projectRoleAssertion" "projectRoleCheck" ]
                  |> withName name
                  |> withRef "org" org 
                  |> toResource name
              );

              zitadel_application_oidc = cfg.organization |> select [ "project" "application" ] (org: project: name: value: 
                value 
                  |> getAttrs [ "redirectUris" "grantTypes" "responseTypes" ]
                  |> withName name
                  |> withRef "org" org 
                  |> withRef "project" project 
                  |> toResource name
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
    ];

    systemd.services.zitadelApplyTerraform = {
      description = "Zitadel terraform apply";

      wantedBy = [ "multi-user.target" ];
      wants = [ "zitadel.service" ];
      
      script = ''
        #!/usr/bin/env bash

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
        # masterKeyFile = config.sops.secrets."zitadel/masterKey".path;
        masterKeyFile = "/var/lib/zitadel/master_key";
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

          # DefaultInstance = {
          #   # PasswordComplexityPolicy = {
          #   #   MinLength = 0;
          #   #   HasLowercase = false;
          #   #   HasUppercase = false;
          #   #   HasNumber = false;
          #   #   HasSymbol = false;
          #   # };
          #   LoginPolicy = {
          #     AllowRegister = false;
          #     ForceMFA = true;
          #   };
          #   LockoutPolicy = {
          #     MaxPasswordAttempts = 5;
          #     MaxOTPAttempts = 10;
          #   };
          #   # SMTPConfiguration = {
          #   #   SMTP = {
          #   #     Host = "black-mail.nl:587";
          #   #     User = "chris@kruining.eu";
          #   #     Password = "__TODO_USE_SOPS__";
          #   #   };
          #   #   FromName = "Amarth Zitadel";
          #   # };
          # };

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
    sops.secrets."zitadel/masterKey" = {
      owner = "zitadel";
      group = "zitadel";
      restartUnits = [ "zitadel.service" ];
    };
  };
}
