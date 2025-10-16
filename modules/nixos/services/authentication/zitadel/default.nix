{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.authentication.zitadel;

  database = "zitadel";
in
{
  options.${namespace}.services.authentication.zitadel = {
    enable = mkEnableOption "Zitadel";
  };

  config = mkIf cfg.enable {
    ${namespace}.services.persistance.postgresql.enable = true;

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

          ExternalDomain = "auth.kruining.eu";
          ExternalPort = 443;
          ExternalSecure = true;

          Metrics.Type = "otel";
          Tracing.Type = "otel";
          Telemetry.Enabled = true;

          SystemDefaults = {
            PasswordHasher.Hasher.Algorithm = "argon2id";
            SecretHasher.Hasher.Algorithm = "argon2id";
          };

          DefaultInstance = {
            PasswordComplexityPolicy = {
              MinLength = 20;
              HasLowercase = false;
              HasUppercase = false;
              HasNumber = false;
              HasSymbol = false;
            };
            LoginPolicy = {
              AllowRegister = false;
              ForceMFA = true;
            };
            LockoutPolicy = {
              MaxPasswordAttempts = 5;
              MaxOTPAttempts = 10;
            };
            SMTPConfiguration = {
              SMTP = {
                Host = "black-mail.nl:587";
                User = "chris@kruining.eu";
                Password = "__TODO_USE_SOPS__";
              };
              FromName = "Amarth Zitadel";
            };
          };

          Database.postgres = {
            Host = "localhost";
            # Zitadel will report error if port is not set
            Port = 5432;
            Database = database;
            User = {
              Username = database;
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
            InstanceName = "auth.kruining.eu";
            Org = {
              Name = "Amarth";
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
        ensureDatabases = [ database ];
        ensureUsers = [
          {
            name = database;
            ensureDBOwnership = true;
          }
        ];
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "auth.kruining.eu".extraConfig = ''
            reverse_proxy h2c://127.0.0.1:9092
          '';
        };
        extraConfig = ''
          (auth-z) {
            forward_auth h2c://127.0.0.1:9092 {
              uri /api/authz/forward-auth
              copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
            }
          }
        '';
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
