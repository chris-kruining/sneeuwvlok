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
        "${service}" =
          {
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
          }
          // (lib.optionalAttrs (service != "prowlarr") {
            user = service;
            group = "media";
          });
      }))
      |> lib.mkMerge
      |> (set:
        set
        // {
          qbittorrent = {
            enable = true;
            openFirewall = true;
            webuiPort = 2008;

            serverConfig = {
              LegalNotice.Accepted = true;

              Prefecences.WebUI = {
                Username = "admin";
              };
            };

            user = "qbittorrent";
            group = "media";
          };

          # port is harcoded in nixpkgs module
          sabnzbd = {
            enable = true;
            openFirewall = true;
            configFile = "${cfg.path}/sabnzbd/config.ini";

            user = "sabnzbd";
            group = "media";
          };

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

    systemd.services =
      cfg
      |> lib.mapAttrsToList (service: {
        enable,
        debug,
        port,
        rootFolders,
        ...
      }: (mkIf enable {
        "${service}ApplyTerraform" = let
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
                    version =
                      {
                        radarr = "2.3.3";
                        sonarr = "3.4.0";
                        prowlarr = "3.1.0";
                        lidarr = "1.13.0";
                        readarr = "2.1.0";
                        whisparr = "1.2.0";
                      }.${
                        service
                      };
                  };

                  provider.${service} = {
                    url = "http://127.0.0.1:${toString port}";
                    api_key = lib.tfRef "var.api_key";
                  };

                  resource = {
                    "${service}_root_folder" = mkIf (lib.elem service ["radarr" "sonarr" "whisparr"]) (
                      rootFolders
                      |> lib.imap (i: f: lib.nameValuePair "local${toString i}" {path = f;})
                      |> lib.listToAttrs
                    );
                  };
                };
              })
            ];
          };
        in {
          description = "${service} terraform apply";

          wantedBy = ["multi-user.target"];
          wants = ["${service}.service"];

          preStart = ''
            install -d -m 0770 -o ${service} -g media /var/lib/${service}ApplyTerraform
            ${
              rootFolders
              |> lib.map (folder: "install -d -m 0770 -o media -g media ${folder}")
              |> lib.join "\n"
            }
          '';

          script = ''
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
            ${lib.getExe pkgs.opentofu} init -upgrade

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
            Group = "media";

            WorkingDirectory = "/var/lib/${service}ApplyTerraform";

            EnvironmentFile = [
              config.sops.templates."${service}/config.env".path
            ];
          };
        };
      }))
      |> lib.mkMerge;

    users =
      cfg
      |> lib.mapAttrsToList (service: {enable, ...}: (mkIf enable {
        users.${service} = {
          isSystemUser = true;
          group = lib.mkDefault service;
          extraGroups = ["media"];
        };
        groups.${service} = {};
      }))
      |> lib.mkMerge;

    sops =
      cfg
      |> lib.mapAttrsToList (service: {enable, ...}: (mkIf enable {
        secrets."${service}/apikey" = {
          owner = service;
          group = "media";
          restartUnits = ["${service}.service"];
        };

        templates = {
          "${service}/config.env" = {
            owner = service;
            group = "media";
            restartUnits = ["${service}.service"];
            content = ''
              ${lib.toUpper service}__AUTH__APIKEY="${config.sops.placeholder."${service}/apikey"}"
            '';
          };

          "${service}/config.tfvars" = {
            owner = service;
            group = "media";
            restartUnits = ["${service}.service"];
            content = ''
              api_key = "${config.sops.placeholder."${service}/apikey"}"
            '';
          };
        };
      }))
      |> lib.mkMerge;
  };
}
