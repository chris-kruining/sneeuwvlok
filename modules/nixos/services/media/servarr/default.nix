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
  inherit (lib) mkIf mkMerge mkEnableOption mkOption types;

  cfg = config.${namespace}.services.media.servarr;
  servarr = import ./lib.nix {inherit lib;};
  anyEnabled = cfg |> lib.attrNames |> lib.length |> (l: l > 0);

  # The sabnzbd category each service downloads into, and the name of the setting for it
  sabnzbdCategory = {
    radarr = {movie_category = "movies";};
    sonarr = {tv_category = "tv";};
    lidarr = {music_category = "audio";};
    whisparr = {movie_category = "movies";};
  };

  # Sabnzbd's ini is generated from nix (allowConfigWrite = false), so the categories have to be declared
  sabnzbdCategories =
    cfg
    |> lib.filterAttrs (service: {enable, ...}: enable && sabnzbdCategory ? ${service})
    |> lib.mapAttrsToList (service: _: lib.head (lib.attrValues sabnzbdCategory.${service}))
    |> lib.unique
    |> lib.imap1 (order: name:
      lib.nameValuePair name {
        inherit name order;
        pp = "";
        script = "Default";
        # Completed downloads go straight into complete_dir
        dir = "";
        priority = -100;
      })
    |> lib.listToAttrs;
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
                # bindaddress = "0.0.0.0";
                bindaddress = "[::]";
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
            webuiPort = 2080;
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
                port = 2090;
                host_whitelist = "${config.networking.hostName}";

                permissions = "770";
                download_dir = "/var/media/downloads/incomplete";
                complete_dir = "/var/media/downloads/done";
              };

              categories =
                {
                  "*" = {
                    name = "*";
                    order = 0;
                    pp = 3;
                    script = "None";
                    dir = "";
                    priority = 0;
                  };
                }
                // sabnzbdCategories;

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
            port = 2070;
          };

          postgresql = let
            databases = [] ++ (cfg |> lib.attrNames);
          in {
            ensureDatabases = databases;
            ensureUsers =
              databases
              |> lib.map (service: {
                name = service;
                ensureDBOwnership = true;
              });
          };
        }
      ]
      |> lib.mkMerge;

    ${namespace}.services.tofu.workspaces =
      cfg
      |> lib.mapAttrsToList (service: {
        enable,
        debug,
        port,
        rootFolders,
        ...
      }: (mkIf enable {
        "${service}" = let
          config' = config;
          lib' = lib;
          ping = s: "http://127.0.0.1:${toString cfg.${s}.port}/ping";
          others = cfg |> lib.filterAttrs (s: c: s != service && c.enable) |> lib.attrNames;
        in {
          description = "${service} tofu apply";
          mode =
            if debug
            then "plan"
            else "apply";

          user = service;
          group = "media";

          providers."devopsarr/${service}" = inputs."tofu-provider-${service}";

          # Download clients and prowlarr's applications are tested against the other services when saved
          after =
            ["${service}.service" "postgresql.service" "qbittorrent.service" "sabnzbd.service"]
            ++ lib.optionals (service == "prowlarr") (others |> lib.map (s: "${s}.service"));
          waitFor =
            [(ping service)]
            ++ lib.optionals (service == "prowlarr") (others |> lib.map ping);

          varFiles = [config.sops.templates."servarr/config.tfvars".path];
          environmentFiles = [config.sops.templates."${service}/config.env".path];
          legacyStateFile = "/var/lib/${service}ApplyTerraform/terraform.tfstate";

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

                provider.${service} = {
                  url = "http://127.0.0.1:${toString port}";
                  api_key = lib.tfRef "var.${service}_api_key";
                };

                resource =
                  {
                    "${service}_notification_webhook" = mkIf (lib.elem service ["radarr" "sonarr" "whisparr" "lidarr" "readarr"]) {
                      "arrtrix" = mkMerge [
                        {
                          method = 1; # HTTP METHOD 1=POST, 2=PUT
                          name = "Arrtrix";
                          url = "http://localhost:${toString config'.services.arrtrix.settings.appservice.port}/_arrtrix/webhook";

                          on_grab = true;
                          on_rename = true;
                          on_upgrade = true;
                        }
                        (lib.optionalAttrs (lib.elem service ["radarr" "sonarr" "whisparr"]) {
                          on_download = true;
                        })
                        (lib.optionalAttrs (lib.elem service ["radarr" "whisparr"]) {
                          on_movie_delete = true;
                        })
                      ];
                    };

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
                        port = 2080;
                      };
                    };

                    "${service}_download_client_sabnzbd" = mkIf (lib.elem service ["radarr" "sonarr" "lidarr" "whisparr"]) {
                      "main" =
                        {
                          name = "SABnzbd";
                          enable = true;
                          priority = 1;
                          host = "localhost";
                          api_key = lib.tfRef "var.sabnzbd_api_key";
                          url_base = "/";
                          port = 2090;
                        }
                        // sabnzbdCategory.${service};
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
                        # Keeps the indexers in the apps up to date, addOnly never updates their prowlarr url or api key
                        sync_level = "fullSync";
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
      }))
      |> lib.mkMerge;

    systemd.tmpfiles.rules =
      cfg
      |> lib.attrValues
      |> lib.filter (s: s.enable)
      |> lib.concatMap (s: s.rootFolders)
      |> lib.map (folder: "d ${folder} 0770 media media -");

    # qBittorrent writes its settings back when it stops, so the configuration is installed right
    # before it starts. From an activation script it would be overwritten by the stop that follows.
    systemd.services.qbittorrent.preStart = ''
      install -Dm0600 ${config.sops.templates."qbittorrent/qBittorrent.conf".path} \
        ${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf
    '';

    # The apps reach their indexers through prowlarr with prowlarr's api key, but prowlarr doesn't update the key of
    # an indexer it already added (not even with fullSync). So when the key changes the indexers are removed from the
    # apps and prowlarr adds them again, with the current key. Started by sops when `prowlarr/apikey` changes.
    systemd.services.prowlarr-resync-indexers = mkIf (cfg.prowlarr.enable or false) (let
      prowlarr = "http://127.0.0.1:${toString cfg.prowlarr.port}";
      # The url prowlarr gives the indexers, see prowlarr_url of the applications
      indexerUrl = "http://localhost:${toString cfg.prowlarr.port}/";

      apps =
        cfg
        |> lib.filterAttrs (s: c: c.enable && lib.elem s ["radarr" "sonarr" "lidarr" "whisparr"])
        |> lib.mapAttrsToList (s: {port, ...}: {
          name = s;
          url = "http://127.0.0.1:${toString port}/api/${if s == "lidarr" then "v1" else "v3"}";
        });
    in {
      description = "Let prowlarr add its indexers to the apps again, with its current api key";
      after = ["prowlarr.service"] ++ map (app: "${app.name}.service") apps;
      requires = ["prowlarr.service"];

      path = [pkgs.curl pkgs.jq];

      script = ''
        api() {
          local key=$1; shift
          curl --silent --show-error --fail --header "X-Api-Key: $(cat "$CREDENTIALS_DIRECTORY/$key")" "$@"
        }

        # Prowlarr and the apps may still be starting after the key changed
        wait_for() {
          until api "$1" --output /dev/null "$2/system/status"; do
            if (( SECONDS > 300 )); then
              echo "$1 did not become ready"
              exit 1
            fi
            sleep 2
          done
        }

        wait_for prowlarr "${prowlarr}/api/v1"

        ${apps |> map (app: ''
          wait_for ${app.name} "${app.url}"

          for id in $(api ${app.name} "${app.url}/indexer"             | jq -r --arg url "${indexerUrl}" '.[] | select(any(.fields[]; .name == "baseUrl" and ((.value // "") | startswith($url)))) | .id'); do
            echo "removing indexer $id from ${app.name}"
            api ${app.name} --request DELETE "${app.url}/indexer/$id"
          done
        '') |> lib.join "
"}

        api prowlarr --header "Content-Type: application/json" --data '{"name":"ApplicationIndexerSync"}'           --output /dev/null "${prowlarr}/api/v1/command"
      '';

      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        LoadCredential =
          ["prowlarr:${config.sops.secrets."prowlarr/apikey".path}"]
          ++ map (app: "${app.name}:${config.sops.secrets."${app.name}/apikey".path}") apps;
      };
    });

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
          restartUnits = ["${service}.service"] ++ lib.optional (service == "prowlarr") "prowlarr-resync-indexers.service";
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
              # Merged into sabnzbd.ini when it starts
              restartUnits = ["sabnzbd.service"];
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
