{ config, lib, pkgs, ... }:
let
inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  user = "authelia-testing";
in
{
  options.modules.services.auth = {
    enable = mkEnableOption "Auth";
  };

  config = mkIf config.modules.services.auth.enable {
    environment.systemPackages = with pkgs; [
      authelia
    ];

    services.authelia.instances.testing = {
      enable = true;

      secrets = {
        storageEncryptionKeyFile = "/etc/authelia/testing/storageEncryptionKeyFile";
        jwtSecretFile = "/etc/authelia/testing/jwtSecretFile";
        sessionSecretFile = "/etc/authelia/testing/sessionSecrets";
      };

      settings = {
        theme = "auto";

        server = {
          address = "tcp://127.0.0.1:9091";
        };

        log = {
          level = "info";
          format = "json";
        };

        authentication_backend.file.path = "/etc/authelia/testing/users_database.yml";

        access_control = {
          default_policy = "deny";

          rules = [
            {
              domain = ["auth.kruining.eu"];
              policy = "bypass";
            }
            {
              domain = ["*.kruining.eu"];
              policy = "one_factor";
            }
          ];
        };

        session = {
          name = "authelia_testing_session";
          expiration = "12h";
          inactivity = "45m";
          remember_me = "1m";
          # redis.host = "/run/redis-authelia-testing/redis.sock";
          cookies = [
            {
              domain = "kruining.eu";
              authelia_url = "https://auth.kruining.eu";
              default_redirection_url = "https://kaas.kruining.eu";
              name = "authelia_session";
            }
          ];
        };

        regulation = {
          max_retries = 300;
          find_time = "5m";
          ban_time = "15m";
        };

        storage = {
          local.path = "/var/authelia/testing/db.sqlite3";
        };

        notifier = {
          disable_startup_check = false;
          filesystem.filename = "/var/authelia/testing/notifications.txt";
        };

        # identity_providers.oidc.clients = [];
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d /var/authelia/testing 400 ${user} ${user} -"
      ];
    };

    # These should not be set from nix but through other means to not leak the secret!
    # This is purely for testing purposes!
    environment.etc = {
      "authelia/testing/storageEncryptionKeyFile" = {
        mode = "0400";
        user = user;
        text = "you_must_generate_a_random_string_of_more_than_twenty_chars_and_configure_this";
      };

      "authelia/testing/jwtSecretFile" = {
        mode = "0400";
        user = user;
        text = "a_very_important_secret";
      };

      "authelia/testing/sessionSecrets" = {
        mode = "0400";
        user = user;
        text = "some_session_secrets";
      };

      "authelia/testing/users_database.yml" = {
        mode = "0400";
        user = user;
        text = ''
          users:
            chris:
              disabled: false
              displayname: chris
              # password of password
              password: $argon2id$v=19$m=65536,t=3,p=4$2ohUAfh9yetl+utr4tLcCQ$AsXx0VlwjvNnCsa70u4HKZvFkC8Gwajr2pHGKcND/xs
              email: chris@kruining.eu
              groups:
                - admin
                - dev
        '';
      };
    };

    services.caddy = {
      enable = true;
      virtualHosts = {
        "auth.kruining.eu".extraConfig = ''
          reverse_proxy authelia:9091
        '';
        "kaas.kruining.eu".extraConfig = ''
          import auth

          respond "KAAS"
        '';
      };
      extraConfig = ''
        (auth) {
          forward_auth authelia:9091 {
            uri /api/authz/forward-auth
            copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
          }
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
