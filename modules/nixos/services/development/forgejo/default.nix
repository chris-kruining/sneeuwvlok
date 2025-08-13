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
    services = {
      forgejo = {
        enable = true;
        database.type = "postgres";

        settings = {
          server = {
            DOMAIN = domain;
            ROOT_URL = "https://${domain}/";
            HTTP_PORT = 5002;
          };

          service = {
            DISABLE_REGISTRATION = true;
            ALLOW_ONLY_EXTERNAL_REGISTRATION = false;
            SHOW_REGISTRATION_BUTTON = false;
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
            import auth

            reverse_proxy http://127.0.0.1:5002
          '';
        };
      };
    };
  };
}
