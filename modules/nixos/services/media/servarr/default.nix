{
  pkgs,
  config,
  lib,
  namespace,
  terranixLib,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.${namespace}.services.media.servarr;
  servarr = import ./lib.nix {inherit lib;};
  anyEnabled = cfg |> lib.attrNames |> lib.length |> (l: l > 0);
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

  config = mkIf anyEnabled {
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
          // (lib.optionalAttrs (lib.elem service ["radarr" "sonarr" "lidarr" "whisparr"]) {
            user = service;
            group = "media";
          });
      }))
      |> lib.concat [
        {
          qbittorrent = {
            enable = true;
            openFirewall = true;
            webuiPort = 2008;
            serverConfig = lib.mkForce {};

            user = "qbittorrent";
            group = "media";
          };

          sabnzbd = {
            enable = true;
            openFirewall = true;

            allowConfigWrite = false;
            configFile = lib.mkForce null;

            secretFiles = [
              config.sops.templates."sabnzbd/config.ini".path
            ];

            settings = {
              misc = {
                host = "0.0.0.0";
                port = 2009;
                host_whitelist = "${config.networking.hostName}";

                download_dir = "/var/media/downloads/incomplete";
                complete_dir = "/var/media/downloads/done";
              };

              servers = {
                "news.sunnyusenet.com" = {
                  name = "news.sunnyusenet.com";
                  displayname = "news.sunnyusenet.com";
                  host = "news.sunnyusenet.com";
                  port = 563;
                  timeout = 60;
                };
              };
            };

            user = "sabnzbd";
            group = "media";
          };

          flaresolverr = {
            enable = true;
            openFirewall = true;
            port = 2007;
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
        }
      ]
      |> lib.mkMerge;

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
          config' = config;
          lib' = lib;

          terraformConfiguration = terranixLib.terranixConfiguration {
            system = pkgs.stdenv.hostPlatform.system;

            modules = [
              ({
                config,
                lib,
                ...
              }: {
                config = {
                  variable =
                    cfg
                    |> lib'.mapAttrsToList (s: _: {
                      "${s}_api_key" = {
                        type = "string";
                        description = "${s} API key";
                      };
                    })
                    |> lib'.concat [
                      {
                        qbittorrent_api_key = {
                          type = "string";
                          description = "qbittorrent api key";
                        };

                        sabnzbd_api_key = {
                          type = "string";
                          description = "sabnzbd api key";
                        };
                      }
                    ]
                    |> lib'.mkMerge;

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
                    api_key = lib.tfRef "var.${service}_api_key";
                  };

                  resource =
                    {
                      "${service}_root_folder" = mkIf (lib.elem service ["radarr" "sonarr" "whisparr"]) (
                        rootFolders
                        |> lib.imap (i: f: lib.nameValuePair "local${toString i}" {path = f;})
                        |> lib.listToAttrs
                      );

                      "${service}_download_client_qbittorrent" = mkIf (lib.elem service ["radarr" "sonarr" "lidarr" "whisparr"]) {
                        "main" = {
                          name = "qBittorrent";
                          enable = true;
                          priority = 1;
                          host = "localhost";
                          username = "admin";
                          password = lib.tfRef "var.qbittorrent_api_key";
                          url_base = "/";
                          port = 2008;
                        };
                      };

                      "${service}_download_client_sabnzbd" = mkIf (lib.elem service ["radarr" "sonarr" "lidarr" "whisparr"]) {
                        "main" = {
                          name = "SABnzbd";
                          enable = true;
                          priority = 1;
                          host = "localhost";
                          api_key = lib.tfRef "var.sabnzbd_api_key";
                          url_base = "/";
                          port = 2009;
                        };
                      };
                    }
                    // (lib.optionalAttrs (service == "prowlarr") (
                      cfg
                      |> lib'.filterAttrs (s: _: lib'.elem s ["radarr" "sonarr" "lidarr" "whisparr"])
                      |> lib'.mapAttrsToList (s: {port, ...}: {
                        "prowlarr_application_${s}"."main" = let
                          p = cfg.prowlarr.port or config'.services.prowlarr.settings.server.port or 9696;
                        in {
                          name = s;
                          sync_level = "addOnly";
                          base_url = "http://localhost:${toString port}";
                          prowlarr_url = "http://localhost:${toString p}";
                          api_key = lib.tfRef "var.${s}_api_key";
                          # sync_categories = [3000 3010 3030];
                        };
                      })
                      |> lib'.concat [
                        {
                          "prowlarr_indexer" = {
                            "nyaa" = {
                              enable = true;

                              app_profile_id = 1;
                              priority = 1;

                              name = "Nyaa";
                              implementation = "Cardigann";
                              config_contract = "CardigannSettings";
                              protocol = "torrent";

                              fields = [
                                {
                                  name = "definitionFile";
                                  text_value = "nyaasi";
                                }
                                {
                                  name = "baseSettings.limitsUnit";
                                  number_value = 0;
                                }
                                {
                                  name = "torrentBaseSettings.preferMagnetUrl";
                                  bool_value = false;
                                }
                                {
                                  name = "prefer_magnet_links";
                                  bool_value = true;
                                }
                                {
                                  name = "sonarr_compatibility";
                                  bool_value = false;
                                }
                                {
                                  name = "strip_s01";
                                  bool_value = false;
                                }
                                {
                                  name = "radarr_compatibility";
                                  bool_value = false;
                                }
                                {
                                  name = "filter-id";
                                  number_value = 0;
                                }
                                {
                                  name = "cat-id";
                                  number_value = 0;
                                }
                                {
                                  name = "sort";
                                  number_value = 0;
                                }
                                {
                                  name = "type";
                                  number_value = 1;
                                }
                              ];
                            };
                          };
                        }
                      ]
                      |> lib'.mkMerge
                    ));
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

          script = lib.replaceStrings ["\r"] [""] ''
            # Sleep for a bit to give the service a chance to start up
            sleep 5s

            if [ "$(systemctl is-active ${lib.escapeShellArg service})" != "active" ]; then
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
            -var-file='${config.sops.templates."servarr/config.tfvars".path}'
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

    system.activationScripts.qbittorrent-config = {
      deps = lib.optional (!config.sops.useSystemdActivation) "setupSecrets";
      # TODO: If sops-nix is switched to systemd activation, add a systemd unit
      # for this install step that runs after sops-install-secrets.service,
      # because this activation-script dependency only orders against setupSecrets.
      text = ''
        install -Dm0600 -o ${config.services.qbittorrent.user} -g ${config.services.qbittorrent.group} \
          ${config.sops.templates."qbittorrent/qBittorrent.conf".path} \
          ${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf
      '';
    };

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
      |> lib.concat [
        {
          groups.media = {};
        }
      ]
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
        };
      }))
      |> lib.concat [
        {
          secrets = {
            "qbittorrent/password" = {};
            "qbittorrent/password_hash" = {
              owner = "qbittorrent";
              group = "media";
            };
            "sabnzbd/apikey" = {};
            "sabnzbd/nzbkey" = {};
            "sabnzbd/sunnyweb/username" = {};
            "sabnzbd/sunnyweb/password" = {};
          };

          templates = {
            "servarr/config.tfvars" = {
              owner = "media";
              group = "media";
              mode = "0440";
              restartUnits = cfg |> lib.attrNames |> lib.map (s: "${s}.service");
              content = ''
                ${
                  cfg
                  |> lib.attrNames
                  |> lib.map (s: "${s}_api_key = \"${config.sops.placeholder."${s}/apikey"}\"")
                  |> lib.join "\n"
                }
                qbittorrent_api_key = "${config.sops.placeholder."qbittorrent/password"}"
                sabnzbd_api_key = "${config.sops.placeholder."sabnzbd/apikey"}"
              '';
            };
            "qbittorrent/qBittorrent.conf" = {
              owner = "qbittorrent";
              group = "media";
              mode = "0600";
              restartUnits = ["qbittorrent.service"];
              content = ''
                [LegalNotice]
                Accepted=true

                [Preferences]
                WebUI\AlternativeUIEnabled=true
                WebUI\RootFolder=${pkgs.vuetorrent}/share/vuetorrent
                WebUI\Username=admin
                WebUI\Password_PBKDF2=${config.sops.placeholder."qbittorrent/password_hash"}
              '';
            };
            "sabnzbd/config.ini" = {
              owner = "sabnzbd";
              group = "media";
              mode = "0660";
              content = ''
                [misc]
                api_key = ${config.sops.placeholder."sabnzbd/apikey"}
                nzb_key = ${config.sops.placeholder."sabnzbd/nzbkey"}

                [servers]
                [[news.sunnyusenet.com]]
                username = ${config.sops.placeholder."sabnzbd/sunnyweb/username"}
                password = ${config.sops.placeholder."sabnzbd/sunnyweb/password"}
              '';
            };
          };
        }
      ]
      |> lib.mkMerge;
  };
}
