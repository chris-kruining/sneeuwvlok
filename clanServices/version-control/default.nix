{
  ardaLib,
  lib,
  ...
}: {
  _class = "clan.service";
  manifest = {
    name = "version-control";
    description = "Generic version-control service";
    categories = ["Service" "Development"];
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["gateway" "identity" "persistence" "ports"];
      out = ["gateway" "identity" "observability" "persistence" "ports"];
    };
  };

  roles.default = {
    description = "Forgejo version-control service";
    interface = import ./interface.nix;

    perInstance = {
      exports,
      instanceName,
      machine,
      settings,
      mkExports,
      ...
    }: let
      endpoints = ardaLib.endpoints.forService {
        inherit exports machine instanceName;
        serviceName = "version-control";
      };

      listeners = endpoints.internal ["forgejo"];
      forgejoEndpoint = listeners.forgejo;
    in {
      exports = mkExports {
        ports.claims = listeners.claims;
        persistence.databases = ["forgejo"];

        gateway.services.forgejo = {
          endpoint = forgejoEndpoint;
          routes.default.host = settings.forgejo.domain;
        };

        identity.applications.forgejo = lib.mkIf (settings.identity.provider != null) {
          provider = settings.identity.provider;
          redirectUris = ["${toString listeners.forgejo}/user/oauth2/zitadel/callback"];
        };

        observability.metrics.forgejo.targets = [forgejoEndpoint];
      };

      nixosModule = {
        config,
        lib,
        pkgs,
        ...
      }: let
        mailerSettings = lib.optionalAttrs settings.forgejo.mailer.enable {
          mailer = {
            ENABLED = true;
            PROTOCOL = "smtp+starttls";
            SMTP_ADDR = settings.forgejo.mailer.smtpAddress;
            SMTP_PORT = settings.forgejo.mailer.smtpPort;
            FROM = settings.forgejo.mailer.from;
            USER = settings.forgejo.mailer.user;
            PASSWD_URI = "file:${settings.forgejo.mailer.passwordFile}";
          };
        };
      in {
        config = lib.mkIf (settings.driver == "forgejo") {
          environment.systemPackages = with pkgs; [forgejo];

          services = {
            forgejo = {
              enable = true;
              lfs.enable = true;
              useWizard = false;
              database.type = "postgres";

              settings =
                {
                  DEFAULT = {
                    APP_NAME = settings.forgejo.appName;
                    APP_SLOGAN = settings.forgejo.appSlogan;
                  };

                  server = {
                    DOMAIN = settings.forgejo.domain;
                    ROOT_URL = "https://${settings.forgejo.domain}/";
                    HTTP_PORT = forgejoEndpoint.port;
                    LANDING_PAGE = "explore";
                  };

                  cors = {
                    ENABLED = settings.forgejo.allowedCorsDomains != [];
                    ALLOW_DOMAIN = lib.concatStringsSep "," settings.forgejo.allowedCorsDomains;
                  };

                  security = {
                    INSTALL_LOCK = true;
                    PASSWORD_HASH_ALGO = "argon2";
                    DISABLE_WEBHOOKS = true;
                  };

                  service = {
                    ENABLE_BASIC_AUTHENTICATION = false;
                    DISABLE_REGISTRATION = false;
                    ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
                    SHOW_REGISTRATION_BUTTON = false;
                    DEFAULT_KEEP_EMAIL_PRIVATE = true;
                    DEFAULT_USER_VISIBILITY = "private";
                    DEFAULT_ORG_VISIBILITY = "private";
                    VALID_SITE_URL_SCHEMES = "https";
                  };

                  openid = {
                    ENABLE_OPENID_SIGNIN = settings.identity.provider != null;
                    ENABLE_OPENID_SIGNUP = settings.identity.provider != null;
                    WHITELISTED_URIS = lib.optionalString (settings.identity.provider != null) settings.identity.provider.origin;
                  };

                  oauth2_client = {
                    ENABLE_AUTO_REGISTRATION = true;
                    UPDATE_AVATAR = true;
                    ACCOUNT_LINKING = "auto";
                  };

                  actions.ENABLED = settings.forgejo.runner.enable;
                  metrics.ENABLED = true;
                  mirror.ENABLED = true;
                  session = {
                    PROVIDER = "db";
                    COOKIE_SECURE = true;
                  };
                }
                // mailerSettings;
            };

            openssh.settings.AllowUsers = ["forgejo"];

            gitea-actions-runner = lib.mkIf settings.forgejo.runner.enable {
              package = pkgs.forgejo-runner;
              instances.default = {
                enable = true;
                name = "default";
                url = "https://${settings.forgejo.domain}";
                tokenFile = settings.forgejo.runner.tokenFile;
                labels = settings.forgejo.runner.labels;
                settings.log.level = "info";
              };
            };
          };

          users = lib.mkIf settings.forgejo.runner.enable {
            users."gitea-runner" = {
              isSystemUser = true;
              group = "gitea-runner";
            };
            groups."gitea-runner" = {};
          };
        };
      };
    };
  };
}
