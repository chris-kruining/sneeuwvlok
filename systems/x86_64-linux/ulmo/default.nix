{...}: {
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  networking = {
    interfaces.enp2s0 = {
      ipv6.addresses = [
        {
          address = "2a0d:6e00:1dc9:0::dead:beef";
          prefixLength = 64;
        }
      ];

      useDHCP = true;
    };

    defaultGateway = {
      address = "192.168.1.1";
      interface = "enp2s0";
    };

    defaultGateway6 = {
      address = "fe80::1";
      interface = "enp2s0";
    };
  };

  # Expose amarht cloud stuff like this until I have a proper solution
  services.caddy.virtualHosts = {
    "auth.amarth.cloud".extraConfig = ''
      reverse_proxy http://192.168.1.223:9092
    '';

    "amarth.cloud".extraConfig = ''
      reverse_proxy http://192.168.1.223:8080
    '';
  };

  sneeuwvlok = {
    services = {
      backup.borg.enable = true;

      authentication.zitadel = {
        enable = true;

        organization = {
          nix = {
            user = {
              chris = {
                email = "chris@kruining.eu";
                firstName = "Chris";
                lastName = "Kruining";

                roles = ["ORG_OWNER"];
                instanceRoles = ["IAM_OWNER"];
              };

              kaas = {
                email = "chris+kaas@kruining.eu";
                firstName = "Kaas";
                lastName = "Kruining";
              };
            };

            project = {
              ulmo = {
                projectRoleCheck = true;
                projectRoleAssertion = true;
                hasProjectCheck = true;

                role = {
                  jellyfin = {
                    group = "jellyfin";
                  };
                  jellyfin_admin = {
                    group = "jellyfin";
                  };
                };

                assign = {
                  chris = ["jellyfin" "jellyfin_admin"];
                  kaas = ["jellyfin"];
                };

                application = {
                  jellyfin = {
                    redirectUris = ["https://jellyfin.kruining.eu/sso/OID/redirect/zitadel"];
                    grantTypes = ["authorizationCode"];
                    responseTypes = ["code"];
                  };

                  forgejo = {
                    redirectUris = ["https://git.amarth.cloud/user/oauth2/zitadel/callback"];
                    grantTypes = ["authorizationCode"];
                    responseTypes = ["code"];
                  };

                  vaultwarden = {
                    redirectUris = ["https://vault.kruining.eu/identity/connect/oidc-signin"];
                    grantTypes = ["authorizationCode"];
                    responseTypes = ["code"];
                    exportMap = {
                      client_id = "SSO_CLIENT_ID";
                      client_secret = "SSO_CLIENT_SECRET";
                    };
                  };

                  matrix = {
                    redirectUris = ["https://matrix.kruining.eu/_synapse/client/oidc/callback"];
                    grantTypes = ["authorizationCode"];
                    responseTypes = ["code"];
                  };

                  mydia = {
                    redirectUris = ["http://localhost:2010/auth/oidc/callback"];
                    grantTypes = ["authorizationCode"];
                    responseTypes = ["code"];
                  };

                  grafana = {
                    redirectUris = ["http://localhost:9001/login/generic_oauth"];
                    grantTypes = ["authorizationCode"];
                    responseTypes = ["code"];
                  };
                };
              };
            };

            action = {
              flattenRoles = {
                script = ''
                  (ctx, api) => {
                    if (ctx.v1.user.grants == undefined || ctx.v1.user.grants.count == 0) {
                      return;
                    }

                    const roles = ctx.v1.user.grants.grants.flatMap(({ roles, projectId }) => roles.map(role => projectId + ':' + role));

                    api.v1.claims.setClaim('nix:zitadel:custom', JSON.stringify({ roles }));
                  };
                '';
              };
            };

            triggers = [
              {
                flowType = "customiseToken";
                triggerType = "preUserinfoCreation";
                actions = ["flattenRoles"];
              }
              {
                flowType = "customiseToken";
                triggerType = "preAccessTokenCreation";
                actions = ["flattenRoles"];
              }
            ];
          };
        };
      };

      communication.matrix.enable = true;

      development.forgejo.enable = true;

      networking.ssh.enable = true;

      media.enable = true;
      media.glance.enable = true;
      media.mydia.enable = true;
      media.nfs.enable = true;
      media.servarr = {
        radarr = {
          enable = true;
          port = 2001;
          rootFolders = [
            "/var/media/movies"
          ];
        };

        sonarr = {
          enable = true;
          # debug = true;
          port = 2002;
          rootFolders = [
            "/var/media/series"
          ];
        };

        lidarr = {
          enable = true;
          debug = true;
          port = 2003;
          rootFolders = [
            "/var/media/music"
          ];
        };

        prowlarr = {
          enable = true;
          debug = true;
          port = 2004;
        };
      };

      observability = {
        grafana.enable = true;
        prometheus.enable = true;
        loki.enable = true;
        promtail.enable = true;
        # uptime-kuma.enable = true;
      };

      security.vaultwarden = {
        enable = true;
        database = {
          # type = "sqlite";
          # file = "/var/lib/vaultwarden/state.db";

          type = "postgresql";
          host = "localhost";
          port = 5432;
          sslMode = "disabled";
        };
      };
    };

    editor = {
      nano.enable = true;
    };
  };

  system.stateVersion = "23.11";
}
