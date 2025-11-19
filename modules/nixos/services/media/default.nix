{ pkgs, lib, namespace, config, inputs, system, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption;
  inherit (lib.types) str;

  cfg = config.${namespace}.services.media;

  arr = ["radarr" ];
in
{
  options.${namespace}.services.media = {
    enable = mkEnableOption "Enable media services";

    user = mkOption {
      type = str;
      default = "media";
    };

    group = mkOption {
      type = str;
      default = "media";
    };

    path = mkOption {
      type = str;
      default = "/var/media";
    };
  };

  config = mkIf cfg.enable {
    #=========================================================================
    # Dependencies
    #=========================================================================
    environment.systemPackages = with pkgs; [
      podman-tui
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
      jellyseerr
      mediainfo
      id3v2
      yt-dlp
    ];

    #=========================================================================
    # Prepare system
    #=========================================================================
    users = {
      users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
      };
      groups.${cfg.group} = {};
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.path}/series' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/movies' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/music' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/qbittorrent' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/sabnzbd' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/reiverr/config' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/downloads/incomplete' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.path}/downloads/done' 0700 ${cfg.user} ${cfg.group} - -"
      "d /var/lib/radarrApplyTerraform 0755 ${cfg.user} ${cfg.group} -"
    ];

    #=========================================================================
    # Services
    #=========================================================================
    services = let
      arr-services = 
        arr
        |> lib.imap (i: service: {
          name = service;
          value = {
            enable = true;
            openFirewall = true;

            environmentFiles = [
              config.sops.templates."${service}/config.env".path
            ];

            settings = {
              auth.authenticationMethod = "External";

              server = {
                bindaddress = "0.0.0.0";
                port = 2000 + i;
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
          // (if service != "prowlarr" then { user = cfg.user; group = cfg.group; } else {});
        })
        |> lib.listToAttrs
      ;
    in 
    arr-services // {
      bazarr = {
        enable = true;
        openFirewall = true;
        user = cfg.user;
        group = cfg.group;
        listenPort = 2005;
      };

      # port is harcoded in nixpkgs module
      jellyfin = {
        enable = true;
        openFirewall = true;
        user = cfg.user;
        group = cfg.group;
      };

      flaresolverr = {
        enable = true;
        openFirewall = true;
        port = 2007;
      };

      qbittorrent = {
        enable = true;
        openFirewall = true;
        webuiPort = 2008;

        serverConfig = {
          LegalNotice.Accepted = true;
        };

        user = cfg.user;
        group = cfg.group;
      };

      # port is harcoded in nixpkgs module
      sabnzbd = {
        enable = true;
        openFirewall = true;
        configFile = "${cfg.path}/sabnzbd/config.ini";

        user = cfg.user;
        group = cfg.group;
      };

      postgresql = 
      let
        databases = arr |> lib.concatMap (s: [ s "${s}-log" ]);
      in
      {
        enable = true;
        ensureDatabases = arr;
        ensureUsers = arr |> lib.map (service: {
          name = service;
          ensureDBOwnership = true;
        });
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "jellyfin.kruining.eu".extraConfig = ''
            reverse_proxy http://[::1]:8096
          '';
        };
      };
    };

    systemd.services.radarrApplyTerraform = 
    let
      # this is a nix package, the generated json file to be exact
      terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
        inherit system;

        modules = [
          ({ config, lib, ... }: {
            config = {
              variable = {
                api_key = {
                  type = "string";
                  description = "Radarr api key";
                };
              };

              terraform.required_providers.radarr = {
                source = "devopsarr/radarr";
                version = "2.2.0";
              };

              provider.radarr = {
                url = "http://127.0.0.1:2001";
                api_key = lib.tfRef "var.api_key";
              };

              resource = {
                radarr_root_folder.local = {
                  path = "/var/media/movies";
                };
              };
            };
          })
        ];
      };
    in
    {
      description = "Radarr terraform apply";

      wantedBy = [ "multi-user.target" ];
      wants = [ "radarr.service" ];
      
      script = ''
        #!/usr/bin/env bash

        if [ "$(systemctl is-active radarr)" != "active" ]; then
          echo "Radarr is not running"
          exit 1
        fi

        # Sleep for a bit to give radarr the chance to start up
        sleep 5s

        # Print the path to the source for easier debugging
        echo "config location: ${terraformConfiguration}"

        # Copy infra code into workspace
        cp -f ${terraformConfiguration} config.tf.json

        # Initialize OpenTofu
        ${lib.getExe pkgs.opentofu} init

        # Run the infrastructure code
        # ${lib.getExe pkgs.opentofu} plan -var-file='${config.sops.templates."radarr/config.tfvars".path}'
        ${lib.getExe pkgs.opentofu} apply -auto-approve -var-file='${config.sops.templates."radarr/config.tfvars".path}'
      '';

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;

        WorkingDirectory = "/var/lib/radarrApplyTerraform";

        EnvironmentFile = [
          config.sops.templates."radarr/config.env".path
        ];
      };
    };

    systemd.services.jellyfin.serviceConfig.killSignal = lib.mkForce "SIGKILL";

    sops = {
      secrets =
        arr
        |> lib.map (service: {
          name = "${service}/apikey";
          value = {
            owner = cfg.user;
            group = cfg.group;
            restartUnits = [ "${service}.service" ];
          };
        })
        |> lib.listToAttrs
      ;

      templates = 
        let
          apikeys = 
            arr 
            |> lib.map (service: {
              name = "${service}/config.env";
              value = {
                owner = cfg.user;
                group = cfg.group;
                restartUnits = [ "${service}.service" ];
                content = ''
                  ${lib.toUpper service}__AUTH__APIKEY="${config.sops.placeholder."${service}/apikey"}"
                '';
              };
            })
            |> lib.listToAttrs;

          tfvars = 
            arr
            |> lib.map(service: {
              name = "${service}/config.tfvars";
              value = {
                owner = cfg.user;
                group = cfg.group;
                restartUnits = [ "${service}ApplyTerraform.service" ];
                content = ''
                  api_key = "${config.sops.placeholder."${service}/apikey"}"
                '';
              };
            })
            |> lib.listToAttrs;
        in
        apikeys // tfvars
      ;
    };
  };
}
