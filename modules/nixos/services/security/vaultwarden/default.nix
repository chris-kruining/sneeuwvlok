{ pkgs, config, lib, namespace, ... }:
let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.security.vaultwarden;
in
{
  options.${namespace}.services.security.vaultwarden = {
    enable = mkEnableOption "enable vaultwarden";
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '/var/lib/vaultwarden' 0700 vaultwarden vaultwarden - -"
    ];

    services = {
      vaultwarden = {
        enable = true;
        dbBackend = "postgresql";

        package = pkgs.${namespace}.vaultwarden;

        config = {
          SIGNUPS_ALLOWED = false;
          DOMAIN = "https://vault.kruining.eu";

          ADMIN_TOKEN = "";

          DATABASE_URL = "postgres://localhost:5432/vaultwarden?sslmode=disable";

          WEB_VAULT_ENABLED = true;

          SSO_ENABLED = true;
          SSO_ONLY = true;
          SSO_PKCE = true;
          SSO_AUTH_ONLY_NOT_SESSION = false;
          SSO_ROLES_ENABLED = true;
          SSO_ORGANIZATIONS_ENABLED = true;
          SSO_ORGANIZATIONS_REVOCATION = true;
          SSO_AUTHORITY = "https://auth.amarth.cloud/";
          SSO_SCOPES = "email profile offline_access";
          SSO_AUDIENCE_TRUSTED = "^333297815511892227$";
          SSO_CLIENT_ID = "335178854421299459";
          SSO_CLIENT_SECRET = "";

          ROCKET_ADDRESS = "::1";
          ROCKET_PORT = 8222;
          ROCKET_LOG = "critical";

          SMTP_HOST = "black-mail.nl";
          SMTP_PORT = 587;
          SMTP_SECURITY = "starttls";
          SMTP_USERNAME = "info@amarth.cloud";
          SMTP_PASSWORD = "";
          SMTP_FROM = "info@amarth.cloud";
          SMTP_FROM_NAME = "Chris' Vaultwarden";
        };
      };

      postgresql = {
        enable = true;
        ensureDatabases = [ "vaultwarden" ];
        ensureUsers = [
          {
            name = "vaultwarden";
            ensureDBOwnership = true;
          }
        ];
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "vault.kruining.eu".extraConfig = ''
            encode zstd gzip

            reverse_proxy http://localhost:${toString config.services.vaultwarden.config.ROCKET_PORT} {
              header_up X-Real-IP {remote_host}
            }
          '';
        };
      };
    };
  };
}
