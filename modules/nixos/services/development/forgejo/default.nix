{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.development.forgejo;
  domain = "git.kruining.eu";
in
{
  options.${namespace}.services.development.forgejo = {
    enable = mkEnableOption "Forgejo";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ forgejo ];

    services = {
      forgejo = {
        enable = true;
        useWizard = false;
        database.type = "postgres";

        settings = {
          DEFAULT = {
            APP_NAME = "Chris' Forge";
          };

          server = {
            DOMAIN = domain;
            ROOT_URL = "https://${domain}/";
            HTTP_PORT = 5002;
          };

          security = {
            PASSWORD_HASH_ALGO = "argon2";
          };

          service = {
            REQUIRE_SIGNIN_VIEW = true; # must be signed in to see anything
            DISABLE_REGISTRATION = true;
            ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
            SHOW_REGISTRATION_BUTTON = false;
          };

          openid = {
            ENABLE_OPENID_SIGNIN = true;
            ENABLE_OPENID_SIGNUP = true;
            WHITELISTED_URIS = "https://auth-z.kruining.eu";
          };

          oauth2_client = {
            ENABLE_AUTO_REGISTRATION = true;
            UPDATE_AVATAR = true;
          };

          # actions = {
          #   ENABLED = true;
          #   DEFAULT_ACTIONS_URL = "forgejo";
          # };

          session = {
            COOKIE_SECURE = true;
          };
        };
      };

      # gitea-actions-runner = {
      #   package = pkgs.forgejo-actions-runner;
      #   instances.default = {
      #     enable = true;
      #     name = "monolith";
      #     url = "https://git.kruining.eu";
      #     # Obtaining the path to the runner token file may differ
      #     # tokenFile should be in format TOKEN=<secret>, since it's EnvironmentFile for systemd
      #     tokenFile = config.age.secrets.forgejo-runner-token.path;
      #     labels = [
      #       "ubuntu-latest:docker://node:16-bullseye"
      #       "ubuntu-22.04:docker://node:16-bullseye"
      #       "ubuntu-20.04:docker://node:16-bullseye"
      #       "ubuntu-18.04:docker://node:16-buster"
      #       "native:host"
      #     ];
      #   };
      # };

      caddy = {
        enable = true;
        virtualHosts = {
          ${domain}.extraConfig = ''
            # import auth-z

            # stupid dumb way to prevent the login page and go to zitadel instead
            # be aware that this does not disable local login at all!
            rewrite /user/login /user/oauth2/Zitadel

            reverse_proxy http://127.0.0.1:5002
          '';
        };
      };
    };
  };
}
