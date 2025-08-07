{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.development.forgejo;
  svr = cfg.settings.server;
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
            # DOMAIN = "";
            HTTP_PORT = 5002;
          };

          service.DISABLE_REGISTRATION = true;

          actions = {
            ENABLED = true;
            DEFAULT_ACTIONS_URL = "forgejo";
          };
        };
      };

      gitea-actions-runner = {
        package = pkgs.forgejo-actions-runner;
        instances.default = {
          enable = true;
          name = "monolith";
          url = "https://git.kruining.eu";
          # Obtaining the path to the runner token file may differ
          # tokenFile should be in format TOKEN=<secret>, since it's EnvironmentFile for systemd
          tokenFile = config.age.secrets.forgejo-runner-token.path;
          labels = [
            "ubuntu-latest:docker://node:16-bullseye"
            "ubuntu-22.04:docker://node:16-bullseye"
            "ubuntu-20.04:docker://node:16-bullseye"
            "ubuntu-18.04:docker://node:16-buster"
            "native:host"
          ];
        };
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "git.kruining.eu".extraConfig = ''
            reverse_proxy http://127.0.0.1:5002
          '';
        };
      };
    };
  };
}
