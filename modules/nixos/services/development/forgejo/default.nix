{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption mkOption;

  cfg = config.${namespace}.services.development.forgejo;
  domain = "git.amarth.cloud";
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
            DISABLE_WEBHOOKS = true;
          };

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

      forgejo-runner.instances.default = {
        enable = true;

        settings = {
          log.level = "info";

          runner.labels = [
            "default:docker://nixos/nix:latest"
            "ubuntu:docker://ubuntu:24-bookworm"
            "nix:docker://git.amarth.cloud/amarth/runners/default:latest"
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
    };

    # Registers the runner's secret with forgejo, this is idempotent so it can run on every start
    systemd.services.forgejo-runner-register = {
      description = "Register the forgejo runner";

      wantedBy = ["multi-user.target"];
      requires = ["forgejo.service"];
      after = ["forgejo.service"];
      before = ["forgejo-runner-default.service"];
      requiredBy = ["forgejo-runner-default.service"];

      # forgejo-cli needs the same config and credentials as forgejo itself
      environment = removeAttrs config.systemd.services.forgejo.environment ["PATH"];

      script = ''
        ${lib.getExe config.services.forgejo.package} forgejo-cli actions register \
          --name default \
          --secret-file ${config.sops.secrets."forgejo/action_runner_token".path}
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.services.forgejo.user;
        Group = config.services.forgejo.group;
        WorkingDirectory = config.services.forgejo.stateDir;
        inherit (config.systemd.services.forgejo.serviceConfig) LoadCredential;
      };
    };

    sops.secrets = {
      "forgejo/action_runner_token" = {
        owner = config.services.forgejo.user;
        group = config.services.forgejo.group;
        restartUnits = ["forgejo-runner-register.service" "forgejo-runner-default.service"];
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
