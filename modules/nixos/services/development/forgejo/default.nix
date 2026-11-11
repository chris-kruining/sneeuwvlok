{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption mkOption mapAttrs' nameValuePair imap0 attrValues stringToCharacters concatStrings substring hashString listToAttrs optionalAttrs;

  cfg = config.${namespace}.services.development.forgejo;
  ciDeps = config.${namespace}.services.development.ci-deps;
  domain = "git.amarth.cloud";
  runnerNetwork = "forgejo-runner";
  # The bridge of that network and the port of the runner's cache proxy, which the jobs reach on the host
  runnerBridge = "forgejo0";
  runnerCachePort = 5003;
  runnerToken = config.sops.secrets."forgejo/action_runner_token".path;
  tokens = "/run/forgejo-runner-tokens";

  # A runner of its own for every repository with a store (ci-deps), registered to that repository only. Its jobs
  # get the store at /nix/store and its daemon's socket, which the shared runner can't do per repository
  repoRunners = optionalAttrs ciDeps.enable (listToAttrs (imap0 (i: r: let
      # forgejo takes the uuid from the first 16 characters of the token (as bytes), those come from the name, the
      # rest is derived from the shared runner's secret when registering
      prefix = substring 0 16 (hashString "sha256" "forgejo-runner/${r.repository}");
      hex = c: {"0" = "30"; "1" = "31"; "2" = "32"; "3" = "33"; "4" = "34"; "5" = "35"; "6" = "36"; "7" = "37"; "8" = "38"; "9" = "39"; "a" = "61"; "b" = "62"; "c" = "63"; "d" = "64"; "e" = "65"; "f" = "66";}.${c};
      bytes = concatStrings (map hex (stringToCharacters prefix));
    in
      nameValuePair "ci-${r.name}" (r
        // {
          inherit prefix;
          uuid = "${substring 0 8 bytes}-${substring 8 4 bytes}-${substring 12 4 bytes}-${substring 16 4 bytes}-${substring 20 12 bytes}";
          cachePort = runnerCachePort + 1 + i;
        }))
    (attrValues ciDeps.repositories)));
  runnerCachePorts = [runnerCachePort] ++ map (r: r.cachePort) (attrValues repoRunners);
  # The unit nixpkgs makes of a runner instance
  runnerUnit = name: "forgejo-runner-${(import "${pkgs.path}/nixos/lib/utils.nix" {inherit lib config pkgs;}).escapeSystemdPath name}";

  # forgejo-cli needs the same config and credentials as forgejo itself
  registerService = script: {
    wantedBy = ["multi-user.target"];
    requires = ["forgejo.service"];
    after = ["forgejo.service"];

    environment = removeAttrs config.systemd.services.forgejo.environment ["PATH"];

    inherit script;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = config.services.forgejo.user;
      Group = config.services.forgejo.group;
      WorkingDirectory = config.services.forgejo.stateDir;
      inherit (config.systemd.services.forgejo.serviceConfig) LoadCredential;
    };
  };
in {
  options.${namespace}.services.development.forgejo = {
    enable = mkEnableOption "Forgejo";

    port = mkOption {
      type = lib.types.port;
      default = 5002;
      example = "1234";
      description = ''
        Which port to bind forgejo to
      '';
    };
  };

  config = mkIf cfg.enable {
    ${namespace}.services = {
      persistance.postgresql.enable = true;
      virtualisation.podman.enable = true;

      networking.caddy = {
        hosts = {
          "${domain}" = ''
            # import auth

            # stupid dumb way to prevent the login page and go to zitadel instead
            # be aware that this does not disable local login at all!
            # rewrite /user/login /user/oauth2/Zitadel

            # Prometheus scrapes the metrics locally, they are nobody else's business
            respond /metrics 404

            reverse_proxy http://127.0.0.1:${toString cfg.port}
          '';
        };
      };
    };

    environment.systemPackages = [config.services.forgejo.package];

    services = {
      forgejo = {
        enable = true;
        lfs.enable = true;
        useWizard = false;
        database.type = "postgres";

        settings = {
          DEFAULT = {
            APP_NAME = "Tamin Amarth";
            APP_SLOGAN = "Where code is forged";
          };

          server = {
            DOMAIN = domain;
            ROOT_URL = "https://${domain}/";
            HTTP_PORT = cfg.port;
            LANDING_PAGE = "explore";
          };

          cors = {
            ENABLED = true;
            ALLOW_DOMAIN = "https://*.amarth.cloud";
          };

          security = {
            INSTALL_LOCK = true;
            PASSWORD_HASH_ALGO = "argon2";
            # The push webhook of ci-deps is the only one, and it is local
            DISABLE_WEBHOOKS = false;
          };

          webhook.ALLOWED_HOST_LIST = "loopback";

          ui = {
            EXPLORE_PAGING_NUM = 50;
            ISSUE_PAGING_NUM = 50;
            MEMBERS_PAGING_NUM = 50;
          };

          "ui.meta" = {
            AUTHOR = "Where code is forged!";
            DESCRIPTION = "Self-hosted solution for git, because FOSS is the anvil of the future";
          };

          admin = {
            USER_DISABLED_FEATURES = "manage_gpg_keys";
            EXTERNAL_USER_DISABLE_FEATURES = "manage_gpg_keys";
          };

          service = {
            # Auth
            ENABLE_BASIC_AUTHENTICATION = false;
            DISABLE_REGISTRATION = false;
            ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
            SHOW_REGISTRATION_BUTTON = false;

            # Privacy
            DEFAULT_KEEP_EMAIL_PRIVATE = true;
            DEFAULT_USER_VISIBILITY = "private";
            DEFAULT_ORG_VISIBILITY = "private";

            # Common sense
            VALID_SITE_URL_SCHEMES = "https";
          };

          openid = {
            ENABLE_OPENID_SIGNIN = true;
            ENABLE_OPENID_SIGNUP = true;
            WHITELISTED_URIS = "https://auth.kruining.eu";
          };

          oauth2_client = {
            ENABLE_AUTO_REGISTRATION = true;
            UPDATE_AVATAR = true;
            ACCOUNT_LINKING = "auto";
          };

          actions = {
            ENABLED = true;
            # DEFAULT_ACTIONS_URL = "https://data.forgejo.org";
          };

          other = {
            SHOW_FOOTER_VERSION = false;
            SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
          };

          metrics = {
            ENABLED = true;
          };

          api = {
            ENABLE_SWAGGER = false;
          };

          mirror = {
            ENABLED = true;
          };

          session = {
            PROVIDER = "db";
            COOKIE_SECURE = true;
          };

          mailer = {
            ENABLED = true;
            PROTOCOL = "smtp+starttls";
            SMTP_ADDR = "black-mail.nl";
            SMTP_PORT = 587;
            FROM = "chris@kruining.eu";
            USER = "chris@kruining.eu";
            PASSWD_URI = "file:${config.sops.secrets."forgejo/email".path}";
          };
        };
      };

      openssh.settings.AllowUsers = ["forgejo"];

      forgejo-runner.instances =
        {
          default = {
            enable = true;

            settings = {
              log.level = "info";

              # How many jobs run at the same time, the default is 1
              runner.capacity = 10;

              # Jobs share one pre-made network instead of getting a WORKFLOW-* network each, see the
              # forgejo-runner-network service below
              container.network = runnerNetwork;

              # Temporary, :latest of the runner image is moving and otherwise a stale copy stays cached forever.
              # Replace by an immutable tag once the runners repo is merged in here
              container.force_pull = true;

              # actions/cache and the like talk to the runner's cache proxy on the host (which forwards to its cache
              # server), a fixed port so only it is let in from the jobs' bridge
              cache.proxy_port = runnerCachePort;

              # `nix` is on the runners of the repositories with a store only, see below
              runner.labels = [
                "default:docker://nixos/nix:latest"
                "ubuntu:docker://ubuntu:24-bookworm"
              ];

              # Registered offline by forgejo-runner-register, the uuid is the first 16 characters
              # of forgejo/action_runner_token hex encoded, so update it when rotating that secret
              server.connections.default = {
                url = "https://${domain}";
                uuid = "62343864-3834-6338-3664-663665666338";
              };
            };

            secrets.server.connections.default.token_url = config.sops.secrets."forgejo/action_runner_token".path;
          };
        }
        // mapAttrs' (name: r:
          nameValuePair name {
            enable = true;

            settings = {
              log.level = "info";
              runner.capacity = r.capacity;
              container.network = runnerNetwork;
              cache.proxy_port = r.cachePort;

              # The image as ci-deps tagged it once its closure was in the store, never pulled by the runner
              runner.labels = ["nix:docker://${ciDeps.localImage}"];
              container.force_pull = false;

              # The repository's store read-only, changed only through its daemon: what a job evaluates, substitutes
              # or builds lands in the store, and is there for the next job
              container.options = "-v ${r.store}/nix/store:/nix/store:ro -v ${r.socket}:/nix/var/nix/daemon-socket/socket -e NIX_REMOTE=daemon";
              # The runner drops binds that aren't listed here, also its own
              container.valid_volumes = ["${r.store}/nix/store" r.socket];

              server.connections.default = {
                url = "https://${domain}";
                inherit (r) uuid;
              };
            };

            secrets.server.connections.default.token_url = "${tokens}/${name}";
          })
        repoRunners;
    };

    # 53 is aardvark-dns, the podman module only opens it on `podman+` interfaces
    networking.firewall.interfaces.${runnerBridge} = {
      allowedTCPPorts = [53] ++ runnerCachePorts;
      allowedUDPPorts = [53];
    };

    systemd.services = lib.mkMerge [
      {
        # netavark (2.1.0) fails to create a bridge when the host has ipv6 multicast routes (otbr-agent makes
        # these), because it dumps all routes to find the default mtu and chokes on the multicast family. That
        # lookup is skipped when the network has an explicit mtu, and an existing network never creates a
        # bridge again, so the runner uses this one network instead of creating a new one per job.
        forgejo-runner-network = {
          description = "Create the podman network for the forgejo runner";

          wantedBy = ["multi-user.target"];
          before = ["forgejo-runner-default.service"];
          requiredBy = ["forgejo-runner-default.service"];

          path = [config.virtualisation.podman.package];

          script = ''
            # A network from before the bridge had a fixed name goes, the firewall rule below is for that name
            if podman network exists ${runnerNetwork} \
              && [ "$(podman network inspect --format '{{.NetworkInterface}}' ${runnerNetwork})" != ${runnerBridge} ]; then
              podman network rm --force ${runnerNetwork}
            fi
            podman network exists ${runnerNetwork} \
              || podman network create --opt mtu=1500 --interface-name ${runnerBridge} ${runnerNetwork}
          '';

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };

        # Registers the runners' secrets with forgejo, this is idempotent so it can run on every start
        forgejo-runner-register =
          registerService ''
            ${lib.getExe config.services.forgejo.package} forgejo-cli actions register \
              --name default \
              --secret-file ${runnerToken}
          ''
          // {
            description = "Register the forgejo runner";
            before = ["forgejo-runner-default.service"];
            requiredBy = ["forgejo-runner-default.service"];
          };
      }
      (mapAttrs' (name: r:
        nameValuePair "forgejo-runner-register-${name}" (registerService ''
            umask 077
            mkdir -p ${tokens}
            secret=$(printf '%s %s' "$(cat ${runnerToken})" '${r.repository}' | sha256sum | head -c 24)
            printf %s "${r.prefix}$secret" > ${tokens}/${name}

            ${lib.getExe config.services.forgejo.package} forgejo-cli actions register \
              --name ${name} \
              --scope ${r.repository} \
              --secret-file ${tokens}/${name}
          ''
          // {
            description = "Register the forgejo runner of ${r.repository}";
            path = [pkgs.coreutils];
            before = ["${runnerUnit name}.service"];
            requiredBy = ["${runnerUnit name}.service"];
          }))
      repoRunners)
      (mapAttrs' (name: _:
        nameValuePair (runnerUnit name) {
          requires = ["forgejo-runner-network.service"];
          wants = ["ci-deps-image.service"];
          after = ["forgejo-runner-network.service" "ci-deps-image.service"];
        })
      repoRunners)
    ];

    systemd.tmpfiles.rules = ["d ${tokens} 0700 ${config.services.forgejo.user} ${config.services.forgejo.group} -"];

    sops.secrets = {
      "forgejo/action_runner_token" = {
        owner = config.services.forgejo.user;
        group = config.services.forgejo.group;
        restartUnits = ["forgejo-runner-register.service" "forgejo-runner-default.service"] ++ lib.concatMap (name: ["forgejo-runner-register-${name}.service" "${runnerUnit name}.service"]) (lib.attrNames repoRunners);
      };

      "forgejo/email" = {
        owner = "forgejo";
        group = "forgejo";
        key = "email/chris_kruining_eu";
        restartUnits = ["forgejo.service"];
      };
    };
  };
}
