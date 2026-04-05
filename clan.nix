{
  meta = {
    name = "arda";
    domain = "arda";
    description = "My personal machines at home";
  };

  directory = ./.;

  exportInterfaces = {
    persistence = import ./interfaces/persistence.nix;
    gateway = import ./interfaces/gateway.nix;
  };

  inventory.machines = {
    aule = {
      name = "aule";
      description = "Planned build server.";
      machineClass = "nixos";
      tags = [];
    };
    mandos = {
      name = "mandos";
      description = "Living room Steam box.";
      machineClass = "nixos";
      tags = [
        "capability:mobility:stationary"
        "operational:availability:wake-on-demand"
      ];
    };
    manwe = {
      name = "manwe";
      description = "Main desktop.";
      machineClass = "nixos";
      tags = [
        "capability:mobility:stationary"
        "operational:availability:manual"
      ];
    };
    melkor = {
      name = "melkor";
      description = "Planned machine with no defined role yet.";
      machineClass = "nixos";
      tags = [];
    };
    orome = {
      name = "orome";
      description = "Work laptop.";
      machineClass = "nixos";
      tags = [
        "capability:mobility:portable"
        "operational:availability:manual"
      ];
    };
    tulkas = {
      name = "tulkas";
      description = "Steam Deck.";
      machineClass = "nixos";
      tags = [
        "capability:mobility:portable"
        "operational:availability:manual"
      ];
    };
    ulmo = {
      name = "ulmo";
      description = "Primary self-hosted services machine.";
      machineClass = "nixos";
      tags = [
        "capability:mobility:stationary"
        "operational:availability:always-on"
        "operational:storage:large"
        "operational:role:gateway"
      ];
    };
    varda = {
      name = "varda";
      description = "Planned machine with no defined role yet.";
      machineClass = "nixos";
      tags = [];
    };
    yavanna = {
      name = "yavanna";
      description = "Planned machine with no defined role yet.";
      machineClass = "nixos";
      tags = [];
    };
  };

  inventory.tags = {
    config,
    machines,
    ...
  }: {
    # tag_name = [ "list" "of" "machines" ]
    "capability:hardware:gpu" = [""];
    "capability:hardware:audio" = [""];
    "capability:hardware:bluetooth" = [""];
  };

  inventory.instances = {
    users-chris = {
      module = {
        name = "users";
        input = "clan-core";
      };

      roles.default.machines.mandos.settings = {};
      roles.default.machines.manwe.settings = {};
      roles.default.machines.orome.settings = {};
      roles.default.machines.tulkas.settings = {};

      roles.default.settings = {
        user = "chris";
        groups = ["wheel"];
        prompt = true;
        share = true;
      };
    };

    clanDns = {
      module = {
        name = "dm-dns";
        input = "clan-core";
      };

      roles.default.tags = ["all"];
    };

    gateway = {
      module = {
        name = "gateway";
        input = "self";
      };

      roles.default = {
        tags = ["operational:role:gateway"];

        settings = {
          driver = "caddy";
        };
      };
    };

    persistence = {
      module = {
        name = "persistence";
        input = "self";
      };

      # TODO :: Convert to use tags instead
      roles.default.tags = ["operational:availability:always-on" "operational:storage:large"];
    };

    identity = {
      module = {
        name = "identity";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on"];

        settings = {
          persistence_instance = "persistence";

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

                convex = {
                  projectRoleCheck = true;
                  projectRoleAssertion = true;
                  hasProjectCheck = true;

                  application = {
                    scry = {
                      redirectUris = ["https://nautical-salamander-320.eu-west-1.convex.cloud/api/auth/callback/zitadel"];
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
      };
    };

    servarr = {
      module = {
        name = "servarr";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on"];

        settings = {
          enable = true;

          persistence_instance = "persistence";

          services = {
            sonarr = {
              rootFolders = [
                "/var/media/series"
              ];
            };
            radarr = {
              rootFolders = [
                "/var/media/movies"
              ];
            };
            lidarr = {
              rootFolders = [
                "/var/media/music"
              ];
            };
            prowlarr = {};
          };
        };
      };
    };
  };
}
