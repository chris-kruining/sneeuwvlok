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

    # Lidarr is configured by lidarr-config instead, see there why
    ${namespace}.services.tofu.workspaces =
      cfg
      |> lib.filterAttrs (service: _: service != "lidarr")
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
                import = lib.optional (lib.elem service ["radarr" "sonarr"]) {
                  to = "${service}_delay_profile.default";
                  id = "1";
                };

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

                    # The default profile (id 1) always exists, so it is imported (see `import` below) and not created.
                    # Usenet gets a head start, public trackers are full of fake releases (an .exe posing as an episode)
                    # that show up before the real thing is on usenet.
                    "${service}_delay_profile" = mkIf (lib.elem service ["radarr" "sonarr"]) {
                      "default" = {
                        enable_usenet = true;
                        enable_torrent = true;
                        preferred_protocol = "usenet";
                        usenet_delay = 0;
                        torrent_delay = 120;
                        bypass_if_highest_quality = false;
                        order = 2147483647;
                        tags = [];
                      };
                    };

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
                            # lower wins, nyaa gets the fakes so it ranks below the usenet indexers (nzbgeek is 25)
                            priority = 50;

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

    systemd.services.qbittorrent.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
    };

    # Lidarr's part of what tofu does for the others. Its tofu provider (still v1.13.0) doesn't know lidarr 3, it crashes
    # on the delay profile and refuses its download clients (lidarr 3 renamed `usenet` to `UsenetDownloadProtocol`). So
    # this unit puts the same settings in over lidarr's api: what is declared here is created or updated by name, and
    # what lidarr has besides it is removed, like tofu would
    systemd.services.lidarr-config = mkIf (cfg.lidarr.enable or false) (let
      api = "http://127.0.0.1:${toString cfg.lidarr.port}/api/v1";

      # Lidarr's fields as name -> value, the secrets are the name of a credential, filled in when it runs
      provider = {name, implementation, fields, ...} @ attrs: attrs // {
        configContract = "${implementation}Settings";
        tags = [];
        fields = lib.mapAttrsToList (name: value: {inherit name value;}) fields;
      };

      downloadClients = map provider [
        {
          name = "qBittorrent";
          implementation = "QBittorrent";
          protocol = "TorrentDownloadProtocol";
          enable = true;
          priority = 1;
          fields = {
            host = "localhost";
            port = 2080;
            urlBase = "/";
            username = "admin";
            password = {credential = "qbittorrent";};
          };
        }
        {
          name = "SABnzbd";
          implementation = "Sabnzbd";
          protocol = "UsenetDownloadProtocol";
          enable = true;
          priority = 1;
          fields = {
            host = "localhost";
            port = 2090;
            urlBase = "/";
            apiKey = {credential = "sabnzbd";};
            musicCategory = sabnzbdCategory.lidarr.music_category;
          };
        }
      ];

      notifications = map provider [
        {
          name = "Arrtrix";
          implementation = "Webhook";
          onGrab = true;
          onRename = true;
          onUpgrade = true;
          fields = {
            url = "http://localhost:${toString config.services.arrtrix.settings.appservice.port}/_arrtrix/webhook";
            method = 1; # 1=POST, 2=PUT
          };
        }
      ];

      # The default profile (id 1) always exists. The same as radarr's and sonarr's: usenet first (which makes it the
      # preferred protocol) and two hours ahead of the torrents, see their delay profile
      delays = {
        UsenetDownloadProtocol = 0;
        TorrentDownloadProtocol = 120;
      };

      declared = pkgs.writeText "lidarr-config.json" (builtins.toJSON {
        downloadclient = downloadClients;
        notification = notifications;
      });
    in {
      description = "Configure lidarr's download clients, notifications and delay profile";
      wantedBy = ["multi-user.target"];
      after = ["lidarr.service" "qbittorrent.service" "sabnzbd.service"];
      requires = ["lidarr.service"];
      # Restarted with lidarr, by a new api key for one
      partOf = ["lidarr.service"];
      restartTriggers = [declared (builtins.toJSON delays)];

      path = [pkgs.curl pkgs.jq];

      script = ''
        api() {
          curl --silent --show-error --fail-with-body --header "X-Api-Key: $(cat "$CREDENTIALS_DIRECTORY/lidarr")" "$@"
        }
        put() {
          api --request "$1" --header "Content-Type: application/json" --data @- --output /dev/null "$2"
        }

        until api --output /dev/null "${api}/system/status"; do
          if (( SECONDS > 300 )); then
            echo "lidarr did not become ready"
            exit 1
          fi
          sleep 2
        done

        # The secrets go in by credential, so they stay out of the store
        declared=$(jq \
          --rawfile qbittorrent "$CREDENTIALS_DIRECTORY/qbittorrent" \
          --rawfile sabnzbd "$CREDENTIALS_DIRECTORY/sabnzbd" \
          'walk(if type == "object" and has("credential") then $ARGS.named[.credential] | rtrimstr("\n") else . end)' \
          ${declared})

        # Lidarr masks the secrets it gives back, so they can't be compared. A change of what's declared, a secret too,
        # updates everything once instead
        hash=$(sha256sum <<< "$declared" | cut -d' ' -f1)
        [ "$(cat "$STATE_DIRECTORY/applied" 2>/dev/null)" = "$hash" ] && changed=0 || changed=1
        masked='.fields |= map(select(.privacy == "normal" or .privacy == null))'

        for kind in downloadclient notification; do
          current=$(api "${api}/$kind")

          # Lidarr's schema of every field, the declared ones replace its values. Saving tests the client or webhook
          for name in $(jq -r --arg kind "$kind" '.[$kind][].name' <<< "$declared"); do
            want=$(jq --arg kind "$kind" --arg name "$name" '.[$kind][] | select(.name == $name)' <<< "$declared")
            have=$(jq --arg name "$name" '.[] | select(.name == $name)' <<< "$current")
            base=''${have:-$(api "${api}/$kind/schema" | jq --argjson want "$want" '.[] | select(.implementation == $want.implementation)')}

            merged=$(jq --argjson want "$want" '
              . + ($want | del(.fields))
              | .fields |= map(.name as $n | (($want.fields[] | select(.name == $n) | .value) // null) as $v
                                | if $v != null then .value = $v else . end)' <<< "$base")

            if [ -z "$have" ]; then
              echo "adding $kind $name"
              put POST "${api}/$kind" <<< "$merged"
            elif [ "$changed" = 1 ] || [ "$(jq -S "$masked" <<< "$have")" != "$(jq -S "$masked" <<< "$merged")" ]; then
              echo "updating $kind $name"
              put PUT "${api}/$kind/$(jq -r .id <<< "$have")" <<< "$merged"
            fi
          done

          for id in $(jq -r --arg kind "$kind" --argjson current "$current" \
              '[.[$kind][].name] as $names | $current[] | select(.name | IN($names[]) | not) | .id' <<< "$declared"); do
            echo "removing $kind $id, it isn't declared"
            api --request DELETE --output /dev/null "${api}/$kind/$id"
          done
        done

        current=$(api "${api}/delayprofile/1")
        wanted=$(jq --argjson delays ${lib.escapeShellArg (builtins.toJSON delays)} '
          .bypassIfHighestQuality = false
          | .items = (.items | map(.allowed = true | .delay = ($delays[.protocol] // .delay))
                             | sort_by(.protocol != "UsenetDownloadProtocol"))' <<< "$current")
        if [ "$(jq -S . <<< "$current")" != "$(jq -S . <<< "$wanted")" ]; then
          echo "updating the default delay profile"
          put PUT "${api}/delayprofile/1" <<< "$wanted"
        fi

        echo "$hash" > "$STATE_DIRECTORY/applied"
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        DynamicUser = true;
        StateDirectory = "lidarr-config";
        LoadCredential = [
          "lidarr:${config.sops.secrets."lidarr/apikey".path}"
          "qbittorrent:${config.sops.secrets."qbittorrent/password".path}"
          "sabnzbd:${config.sops.secrets."sabnzbd/apikey".path}"
        ];
      };
    });

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
            api ${app.name} --request DELETE --output /dev/null "${app.url}/indexer/$id"
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
            "qbittorrent/password".restartUnits = lib.optional (cfg.lidarr.enable or false) "lidarr-config.service";
            "qbittorrent/password_hash" = {
              owner = "qbittorrent";
              group = "media";
            };
            "sabnzbd/apikey".restartUnits = lib.optional (cfg.lidarr.enable or false) "lidarr-config.service";
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
                [BitTorrent]
                ExcludedFileNamesEnabled=true
                Session\ExcludedFileNames=*.exe, *.zipx, *.scr, *.bat, *.cmd, *.msi, *.lnk, *.vbs

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
