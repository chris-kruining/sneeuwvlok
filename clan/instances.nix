{
  self,
  inputs,
  ...
}: let
  getExport = {
    serviceName,
    instanceName ? serviceName,
    roleName ? "default",
  }:
    self.clan.exports
    |> inputs.clan-core.lib.getExport {
      inherit serviceName instanceName roleName;
      machineName = "ulmo";
    };

  db = getExport {serviceName = "persistence";} |> (v: v.persistence.endpoints.${v.persistence.driver});
  gateway =
    getExport {
      serviceName = "network";
      roleName = "gateway";
    }
    |> (v: v.gateway);

  provider =
    getExport {
      serviceName = "identity";
    }
    |> (v: v.identity.provider);
in {
  clan.inventory.instances = {
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

    network = {
      module = {
        name = "network";
        input = "self";
      };

      roles.default = {
        tags = ["all"];
        settings = {};
      };

      roles.gateway = {
        tags = ["operational:role:gateway"];

        settings = {
          driver = "caddy";

          services = {
            # forgejo = getExport {serviceName = "identity";} |> (v: v.gateway.services.identity);
            # identity = getExport {serviceName = "version-control";} |> (v: v.gateway.services.forgejo);
            # jellyfin = getExport {serviceName = "media";} |> (v: v.gateway.services.jellyfin);
            # matrix = getExport {serviceName = "communications";} |> (v: v.gateway.services.matrix);
          };
        };
      };
    };

    persistence = {
      module = {
        name = "persistence";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on" "operational:storage:large"];
        settings = {
          driver = "postgresql";
        };
      };
    };

    observability = {
      module = {
        name = "observability";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on"];
        settings = {
          driver = "grafana";
          grafana.host = "grafana.kruining.eu";
          identity.provider = provider;
        };
      };
    };

    backup = {
      module = {
        name = "backup";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on" "operational:storage:large"];
        settings.driver = "borg";
      };
    };

    identity = {
      module = {
        name = "identity";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on"];

        settings = {
          database = db;
          externalDomain = "auth.kruining.eu";

          smtp = {
            senderAddress = "chris@kruining.eu";
            host = "black-mail.nl:587";
            user = "chris@kruining.eu";
          };

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

                  consumers = ["jellyfin" "forgejo" "matrix" "grafana"];

                  application = {
                    vaultwarden = {
                      origin = "https://vault.kruining.eu";
                      callbackPath = "/identity/connect/oidc-signin";
                      grantTypes = ["authorizationCode"];
                      responseTypes = ["code"];
                      exportMap = {
                        client_id = "SSO_CLIENT_ID";
                        client_secret = "SSO_CLIENT_SECRET";
                      };
                    };
                  };
                };

                convex = {
                  projectRoleCheck = true;
                  projectRoleAssertion = true;
                  hasProjectCheck = true;

                  application = {
                    scry = {
                      origin = "https://nautical-salamander-320.eu-west-1.convex.cloud";
                      callbackPath = "/api/auth/callback/zitadel";
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
          database = db;
          mediaPath = "/var/media";

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

    version-control = {
      module = {
        name = "version-control";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on"];

        settings = {
          driver = "forgejo";
          forgejo = {
            domain = "git.amarth.cloud";
            appName = "Tamin Amarth";
            appSlogan = "Where code is forged";
            allowedCorsDomains = ["https://*.amarth.cloud"];
            runner.labels = [
              "default:docker://nixos/nix:latest"
              "ubuntu:docker://ubuntu:24-bookworm"
              "nix:docker://git.amarth.cloud/amarth/runners/default:latest"
            ];
          };
          identity.provider = provider;
        };
      };
    };

    communications = {
      module = {
        name = "communications";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on"];

        settings = {
          driver = "matrix";
          matrix = {
            domain = "kruining.eu";
            serverDomain = "matrix.kruining.eu";
            extraWellKnownDomains = ["darkch.at"];
            adminUsers = ["@chris:kruining.eu"];
            bridges = {
              mautrix-signal = {};
              mautrix-telegram = {};
              mautrix-whatsapp = {};
              arrtrix = {};
            };
            livekit.enable = true;
            turn.enable = true;
          };
          identity.provider = provider;
        };
      };
    };

    media = {
      module = {
        name = "media";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on"];

        settings = {
          driver = "jellyfin";
          mediaPath = "/var/media";

          identity.provider = provider;
        };
      };
    };
  };
}
