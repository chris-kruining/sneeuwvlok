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

      services.caddy = {
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
