{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  system,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.${namespace}.services.media.servarr;
in {
  options.${namespace}.services.media = {
    servarr = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkEnableOption "Enable ${name}";
          debug = mkEnableOption "Use tofu plan instead of tofu apply for ${name} ";

          port = mkOption {
            type = types.port;
          };

          rootFolders = mkOption {
            type = types.listOf types.str;
            default = [];
          };
        };
      }));
      default = {};
    };
  };

  config = {
    services =
      cfg
      |> lib.mapAttrsToList (service: {
        enable,
        port,
        ...
      }: (mkIf enable {
        "${service}" = {
          enable = true;
          openFirewall = true;

          environmentFiles = [
            config.sops.templates."${service}/config.env".path
          ];

          settings = {
            auth.authenticationMethod = "External";

            server = {
              bindaddress = "0.0.0.0";
              port = port;
            };

            postgres = {
              host = "localhost";
              port = "5432";
              user = service;
              maindb = service;
              logdb = service;
            };
          };
        };
      }))
      |> lib.mergeAttrsList
      |> (set:
        set
        // {
          postgresql = {
            ensureDatabases = cfg |> lib.attrNames;
            ensureUsers =
              cfg
              |> lib.attrNames
              |> lib.map (service: {
                name = service;
                ensureDBOwnership = true;
              });
          };
        });

    systemd =
      cfg
      |> lib.mapAttrsToList (service: {
        enable,
        debug,
        port,
        rootFolders,
        ...
      }: (mkIf enable {
        tmpfiles.rules = [
          "d /var/lib/${service}ApplyTerraform 0755 ${service} ${service} -"
        ];

        services."${service}ApplyTerraform" = let
          terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
            inherit system;

            modules = [
              ({
                config,
                lib,
                ...
              }: {
                config = {
                  variable = {
                    api_key = {
                      type = "string";
                      description = "${service} api key";
                    };
                  };

                  terraform.required_providers.${service} = {
                    source = "devopsarr/${service}";
                    version = "2.2.0";
                  };

                  provider.${service} = {
                    url = "http://127.0.0.1:${toString port}";
                    api_key = lib.tfRef "var.api_key";
                  };

                  resource = {
                    "${service}_root_folder" =
                      rootFolders
                      |> lib.imap (i: f: lib.nameValuePair "local${toString i}" {path = f;})
                      |> lib.listToAttrs;
                  };
                };
              })
            ];
          };
        in {
          description = "${service} terraform apply";

          wantedBy = ["multi-user.target"];
          wants = ["${service}.service"];

          script = ''
            #!/usr/bin/env bash

            # Sleep for a bit to give the service a chance to start up
            sleep 5s

            if [ "$(systemctl is-active ${service})" != "active" ]; then
              echo "${service} is not running"
              exit 1
            fi

            # Print the path to the source for easier debugging
            echo "config location: ${terraformConfiguration}"

            # Copy infra code into workspace
            cp -f ${terraformConfiguration} config.tf.json

            # Initialize OpenTofu
            ${lib.getExe pkgs.opentofu} init

            # Run the infrastructure code
            ${lib.getExe pkgs.opentofu} \
            ${
              if debug
              then "plan"
              else "apply -auto-approve"
            } \
            -var-file='${config.sops.templates."${service}/config.tfvars".path}'
          '';

          serviceConfig = {
            Type = "oneshot";
            User = service;
            Group = service;

            WorkingDirectory = "/var/lib/${service}ApplyTerraform";

            EnvironmentFile = [
              config.sops.templates."${service}/config.env".path
            ];
          };
        };
      }))
      |> lib.mergeAttrsList;

    users.users =
      cfg
      |> lib.mapAttrsToList (service: {enable, ...}: (mkIf enable {
        "${service}".extraGroups = ["media"];
      }))
      |> lib.mergeAttrsList;

    sops =
      cfg
      |> lib.mapAttrsToList (service: {enable, ...}: (mkIf enable {
        secrets."${service}/apikey" = {
          owner = service;
          group = service;
          restartUnits = ["${service}.service"];
        };

        templates = {
          "${service}/config.env" = {
            owner = service;
            group = service;
            restartUnits = ["${service}.service"];
            content = ''
              ${lib.toUpper service}__AUTH__APIKEY="${config.sops.placeholder."${service}/apikey"}"
            '';
          };

          "${service}/config.tfvars" = {
            owner = service;
            group = service;
            restartUnits = ["${service}.service"];
            content = ''
              api_key = "${config.sops.placeholder."${service}/apikey"}"
            '';
          };
        };
      }))
      |> lib.mergeAttrsList;
  };

  #   cfg
  #   |> lib.mapAttrsToList  (service: { enable, debug, port, rootFolders, ... }: (mkIf enable {

  #     # sops = {
  #     # };
  #   }))
  #   |> lib.mergeAttrsList
  # ;
}
