{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.authentication.zitadel;

  db_name = "zitadel";
  db_user = "zitadel";
in
{
  options.${namespace}.services.authentication.zitadel = {
    enable = mkEnableOption "Zitadel";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      zitadel
    ];

    services = {
      zitadel = {
        enable = true;
        openFirewall = true;
        # masterKeyFile = config.sops.secrets."zitadel/masterKey".path;
        masterKeyFile = "/var/lib/zitadel/master_key";
        tlsMode = "external";
        settings = {
          Port = 9092;
          Database = {
            Host = "/run/postgresql";
            # Zitadel will report error if port is not set
            Port = 5432;
            Database = db_name;
            User.Username = db_user;
          };
        };
        steps = {
          TestInstance = {
            InstanceName = "Zitadel test";
            Org = {
              Name = "Kruining.eu";
              Human = {
                UserName = "admin";
                Password = "kaas";
              };
            };
          };
        };
      };

      postgresql = {
        enable = true;
        ensureDatabases = [ db_name ];
        ensureUsers = [
          {
            name = db_user;
            ensureDBOwnership = true;
          }
        ];
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "auth-z.kruining.eu".extraConfig = ''
            reverse_proxy h2c://127.0.0.1:9092
          '';
        };
        # extraConfig = ''
        #   (auth) {
        #     forward_auth h2c://127.0.0.1:9092 {
        #       uri /api/authz/forward-auth
        #       copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
        #     }
        #   }
        # '';
      };
    };

    # Secrets
    sops.secrets."zitadel/masterKey" = {
      owner = "zitadel";
      group = "zitadel";
      restartUnits = [ "zitadel.service" ];
    };
  };
}
