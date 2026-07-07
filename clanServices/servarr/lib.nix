{
  self,
  config,
  lib,
  pkgs,
  settings,
  ...
}: let
  inherit (lib) mkIf;

  createGenerator = {
    service,
    options,
    ...
  }: {
    dependencies = ["postgresql"];

    files = {
      api_key = {
        secret = true;
        deploy = true;
        owner = service;
        group = "media";
        restartUnits = ["${service}.service"];
      };
      "config.env" = {
        secret = true;
        deploy = true;
        owner = service;
        group = "media";
        restartUnits = ["${service}.service"];
      };
    };

    runtimeInputs = with pkgs; [pwgen];
    script = ''
      pwgen -s 128 1 > $out/api_key
      cat << EOL > $out/config.env
      ${lib.toUpper service}__AUTH__APIKEY="$(cat $out/api_key)"
      ${lib.toUpper service}__POSTGRES_PASSWORD="$(cat $in/postgresql/${service}_password)"
      EOL
    '';
  };

  createService = {
    service,
    options,
    ...
  }: let
    inherit (builtins) toString;
  in
    {
      enable = true;
      # openFirewall = true;

      environmentFiles = [
        config.clan.core.vars.generators.${service}.files."config.env".path
      ];

      settings = {
        auth.authenticationMethod = "External";

        server = {
          bindaddress = "[::1]";
          port = options.port;
        };

        # Password provided via environment file
        postgres = {
          host = settings.database.host;
          port = toString settings.database.port;
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

  createSystemdService = args @ {
    service,
    options,
    ...
  }: let
    tofu = lib.getExe pkgs.opentofu;
    terraformConfiguration = self.inputs.terranix.lib.terranixConfiguration {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        (createInfra args)
      ];
    };
  in {
    description = "${service} apply infra";

    wantedBy = ["multi-user.target"];
    wants = ["${service}.service"];

    preStart = ''
      install -d -m 0770 -o ${service} -g media /var/lib/infra-${service}
      ${
        options.rootFolders
        |> lib.map (folder: "install -d -m 0770 -o media -g media ${folder}")
        |> lib.join "\n"
      }
    '';

    script = ''
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
      ${tofu} init

      # Run the infrastructure code
      ${tofu} \
      ${
        if options.debug
        then "plan"
        else "apply -auto-approve"
      } \
      -var-file='${config.clan.core.vars.generators.servarr.files."config.tfvars".path}'
    '';

    serviceConfig = {
      Type = "oneshot";
      User = service;
      Group = "media";

      WorkingDirectory = "/var/lib/${service}-apply-infra";

      EnvironmentFile = [
        config.clan.core.vars.generators.${service}.files."config.env".path
      ];
    };
  };

  # Returns a module to be used in a modules list of terranix
  createInfra = {
    service,
    options,
    ...
  }: terra: let
    inherit (terra.lib) tfRef;
  in {
    variable = {
      "${service}_api_key" = {
        type = "string";
        description = "${service} API key";
      };

      qbittorrent_api_key = {
        type = "string";
        description = "qbittorrent api key";
      };

      sabnzbd_api_key = {
        type = "string";
        description = "sabnzbd api key";
      };
    };

    terraform.required_providers.${service} = {
      source = "devopsarr/${service}";
      version =
        {
          radarr = "2.3.5";
          sonarr = "3.4.2";
          prowlarr = "3.2.1";
          lidarr = "1.13.0";
          readarr = "2.1.0";
          whisparr = "1.2.0";
        }.${
          service
        };
    };

    provider.${service} = {
      url = "http://[::1]:${toString options.port}";
      api_key = tfRef "var.${service}_api_key";
    };

    resource =
      {
        "${service}_root_folder" = mkIf (lib.elem service ["radarr" "sonarr" "whisparr" "readarr"]) (
          options.rootFolders
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
            password = tfRef "var.qbittorrent_api_key";
            url_base = "/";
            port = config.services.qbittorrent.webuiPort;
          };
        };

        "${service}_download_client_sabnzbd" = mkIf (lib.elem service ["radarr" "sonarr" "lidarr" "whisparr"]) {
          "main" = {
            name = "SABnzbd";
            enable = true;
            priority = 1;
            host = "localhost";
            api_key = tfRef "var.sabnzbd_api_key";
            url_base = "/";
            port = config.services.sabnzbd.settings.misc.port;
          };
        };
      }
      // (lib.optionalAttrs (service == "prowlarr") (
        ["radarr" "sonarr" "lidarr" "whisparr"]
        |> lib.map (s: {
          "prowlarr_application_${s}"."main" = let
            p = config.services.prowlarr.settings.server.port or 9696;
          in {
            name = s;
            sync_level = "addOnly";
            base_url = "http://localhost:${toString (config.services.${s}.setting.server.port)}";
            prowlarr_url = "http://localhost:${toString p}";
            api_key = tfRef "var.${s}_api_key";
          };
        })
        |> lib.concat [
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
        |> lib.mkMerge
      ));
  };
in {
  createModule = services: args: {
    config =
      services
      |> lib.attrsToList
      |> lib.imap1 (i: {
        name,
        value,
      }: let
        service = name;
        options = value // {port = 2000 + i;};
      in {
        clan.core.vars.generators.${service} = createGenerator (args // {inherit service options;});
        services.${service} = createService (args // {inherit service options;});

        systemd.services."infra-${service}" = lib.mkIf settings.enable (createSystemdService (args // {inherit service options;}));
      })
      |> lib.mkMerge;
  };
}
