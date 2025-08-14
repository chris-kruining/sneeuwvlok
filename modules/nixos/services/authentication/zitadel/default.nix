{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption mkForce;

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
          ExternalDomain = "auth-z.kruining.eu";
          ExternalPort = 443;
          ExternalSecure = true;

          Database.postgres = {
            Host = "localhost";
            # Zitadel will report error if port is not set
            Port = 5432;
            Database = db_name;
            User = {
              Username = db_user;
              SSL.Mode = "disable";
            };
            Admin = {
              Username = "postgres";
              SSL.Mode = "disable";
            };
          };
        };
        steps = {
          FirstInstance = {
            InstanceName = "auth-z.kruining.eu";
            Org = {
              Name = "Default";
              Human = {
                UserName = "chris";
                FirstName = "Chris";
                LastName = "Kruining";
                Email = {
                  Address = "chris@kruining.eu";
                  Verified = true;
                };
                Password = "KaasIsAwesome1!";
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
        authentication = mkForce ''
          # Generated file, do not edit!
          # TYPE  DATABASE  USER  ADDRESS       METHOD
          local   all       all                 trust
          host    all       all   127.0.0.1/32  trust
          host    all       all   ::1/128       trust
          '';
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
