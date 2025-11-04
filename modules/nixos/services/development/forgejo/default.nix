{ config, lib, pkgs, namespace, ... }:
let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption mkOption;

  cfg = config.${namespace}.services.development.forgejo;
  domain = "git.amarth.cloud";
in
{
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
    };

    environment.systemPackages = with pkgs; [ forgejo ];

    services = {
      forgejo = {
        enable = true;
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

      openssh.settings.AllowUsers = [ "forgejo" ];

      gitea-actions-runner = {
        package = pkgs.forgejo-actions-runner;
        instances.default = {
          enable = true;
          name = "default";
          url = "https://git.amarth.cloud";
          # Obtaining the path to the runner token file may differ
          # tokenFile should be in format TOKEN=<secret>, since it's EnvironmentFile for systemd
          tokenFile = config.sops.secrets."forgejo/action_runner_token".path;
          # token = "ZBetud1F0IQ9VjVFpZ9bu0FXgx9zcsy1x25yvjhw";
          labels = [
            "default:docker://nixos/nix:latest"
            "ubuntu:docker://ubuntu:24-bookworm"
            "nix:docker://git.amarth.cloud/amarth/runners/default:latest"
          ];
          settings = {
            log.level = "info";
          };
        };
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "${domain}".extraConfig = ''
            # import auth

            # stupid dumb way to prevent the login page and go to zitadel instead
            # be aware that this does not disable local login at all!
            # rewrite /user/login /user/oauth2/Zitadel

            reverse_proxy http://127.0.0.1:${toString cfg.port}
          '';
        };
      };
    };

    sops.secrets = {
      "forgejo/action_runner_token" = {
        owner = "gitea-runner";
        group = "gitea-runner";
        restartUnits = [ "gitea-runner-default.service" ];
      };

      "forgejo/email" = {
        owner = "forgejo";
        group = "forgejo";
        key = "email/chris_kruining_eu";
        restartUnits = [ "forgejo.service" ];
      };
    };
  };
}
