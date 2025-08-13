{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  user = "authelia-testing";
  cfg = config.${namespace}.services.authentication.authelia;
in
{
  options.${namespace}.services.authentication.authelia = {
    enable = mkEnableOption "Authelia";
  };

  config = mkIf cfg.enable {
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

        # administration = {
        #   enable = true;
        #   enable_ui = true;
        #   address = "tcp://127.0.0.1:9092";
        #   users = [ "chris" ];
        #   groups = [ "admin" ];
        # };

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
              default_redirection_url = "https://media.kruining.eu";
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
          local.path = "/var/lib/authelia-testing/db.sqlite3";
        };

        notifier = {
          disable_startup_check = false;
          filesystem.filename = "/var/lib/authelia-testing/notifications.txt";
        };

        identity_providers.oidc = {
          jwks = [
            {
              # Authelia wants at least one private RSA key (why not just allow ecdsa is beyond me)
              key = "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCrkJ2iCcGbZwr9\ntWGiQLzL1OV7WoC8OpRIvtVusyJ6YQGkcB9F3PV+wjzBCojIibjMpWci6vq7sZQp\nnttRsXIBRxyhUoWcg1X8zR2ebFPMqPkfQEYhCPxts/5iaVwESt+77RAeaoJu6Va4\n6ugCHUsujMDGNhXNHWNn1euXT/jnTID8zT2eff8XYItK/vAJgv9ZbDDcamZFqNAK\nWBLGQZGO5GGCDtp99yFlGgG8zhaYpqw/eC/DhRr/O0N0PkQBRsD0mJ5aWCeVIVKB\nP/W35L23XFlgupOcWpZ4Bf7ivjxfakBHq/yYcvq60a9LjwLW+QXyvdvWe7jdV+Bp\nON9VlJ1PAgMBAAECggEANT8o7UWB5S1R5/QHXUgiUFC++E3abpDvvLQdocHPDZRV\n4ic6TYCKYND/8hnG4hZ8WGdtXxT2xJIUneZDw1MDQwpDBH6MIUtRwKgYbTbJu1cm\nGmDkYxRa4+FdLkXs3Rgv4C9vNUFxQeMBm1qsrxtQXh4pJlta4NIiK/Pkro2Pfplp\nyKb5E7HhusHiLqezcPhErYnYQmLPtmInqfQnBAsGehiY6ZL3TMIGTo1FDrIEhu9q\nz31WaK8NuNd/bUqiEdFIVtNt3cSOfqCrtC20LwTIYiv/tDz0ahFOCA42vHSdkz35\nnO1dEkP2YCimTHbw9KwHmzkYL6Q2jd89L8/oCe2dYQKBgQDRz2pvfJjdb4FXLRH/\n/iEsDseRu2z2fg7SBNMloTV/dQGpvBgsEZDWlJw7NyIm2rlZ0kkae9QfLECJeT6A\nZuXnOuUDNUBE5/nj2DBC34gHotpErcJBTlKmr/KfILnh1uDVwLizYNQ6KZ6s3EK8\nSvLXNbEDrJ3HkQbs6OPtZsEVawKBgQDRVcCf+8wxdK1AF474F1E9zAvN8i5+6xIW\nb+YUDuueCzJf8h3wU9Chf/ItEtknw1CHQFNOmLodtQJgGzGDG0R6xmQnfUQIsky1\nO3HDs4xlCggfq9AWm+RKr5r3T34CiJfA4ZUq6i2FKNkdQREArJWcC4cjRItZvGj6\nKJ5ZRDBsrQKBgCnD9lYXIX8DEWY/LJQfDI9uqb+S5c/zrBOWrkmRW8rxidE2BkHP\nhVuR3b/T69J8O+VrfO3utH04G+jB3/VDhoSPLsOCuDZ/TzlR8dl+EeAjRPvi8wZ5\nBu7zm4KdyyLv2XXzlVDv949UdafHeOluqgS5RXGLzSTK8+v5OFYr3EfdAoGAJIP4\n3e9mZxobPprdbZljqov1Yy9jvO/0b8WFNOqFX0REvUfWwR1dv046SHKJPs5rNaya\n25L4pEX27BzSPjR7dY812U2YmIvBpbuA1Mp1Kwrc7+lgmxEGeaC4P3u2V2rMTfEL\nvDitSBUgCmJXPO7eCiJYqGZEiJq9FSYQuTGT4OECgYEAjR+dtmZkcszRo77XdXDo\nRFMlx47R5Xk4R2+faYneCkNJ/MqZdeQ3CxcfQFQHpNJb+1kacXusRDvlm2/777fj\nCOLxaxY6akOEG6dkgmWHzzm9JpmZ63g0I9k+C3zbyQnFyNRQmNW2gGCVwekRmAz+\n/a98+6ip2LRkTQYhZ064rfc=\n-----END PRIVATE KEY-----";
            }
          ];
          clients = [
            {
              client_id = "jellyfin";
              client_name = "Jellyfin";
              # af0WDhM6DILapBO.8Puu8IR1tyXLPqQNUoROgx4A8JWVIxRno4IhvXCMaN1zveuJzw1yw2h3
              client_secret = "$pbkdf2-sha512$310000$9C/krTomC0MUJ2QosHwEKA$43H4gm6yaz.fU5eZsN/KxPDuL/S4jPjaNOcAKyU/uz7IVNDSQo71XQ3sqKZITZ/FLYTN5kxTlVUhEMB9Orlh1g";
              token_endpoint_auth_method = "client_secret_post";
              public = false;
              require_pkce = true;
              pkce_challenge_method = "S256";
              authorization_policy = "one_factor";
              userinfo_signed_response_alg = "none";
              consent_mode = "implicit";
              scopes = [ "openid" "profile" "groups" ];
              redirect_uris = [ "https://jellyfin.kruining.eu/sso/OID/redirect/authelia" ];
            }
            {
              client_id = "streamarr";
              client_name = "Streamarr";
              # ZPuiW2gpVV6MGXIJFk5P3EeSW8V_ICgqduF.hJVCKkrnVmRqIQXRk0o~HSA8ZdCf8joA4m_F
              client_secret = "$pbkdf2-sha512$310000$CzZjvJT75bz5z7MjwxsEtg$JtOiIgaY5/HcLLxJgyX4zvsQV9jIoow0e4JdlFsk/LWRDOJ0kc.PzstlYfw7QERTXtJILoWsDqPzmvpneK5Leg";
              public = false;
              require_pkce = true;
              pkce_challenge_method = "S256";
              token_endpoint_auth_method = "client_secret_post";
              authorization_policy = "one_factor";
              userinfo_signed_response_alg = "none";
              consent_mode = "implicit";
              scopes = [ "offline_access" "openid" "email" "picture" "profile" "groups" ];
              redirect_uris = [ "http://localhost:3000/api/auth/oauth2/callback/authelia" ];
            }
            {
              client_id = "forgejo";
              client_name = "forgejo";
              # ZPuiW2gpVV6MGXIJFk5P3EeSW8V_ICgqduF.hJVCKkrnVmRqIQXRk0o~HSA8ZdCf8joA4m_F
              client_secret = "$pbkdf2-sha512$310000$CzZjvJT75bz5z7MjwxsEtg$JtOiIgaY5/HcLLxJgyX4zvsQV9jIoow0e4JdlFsk/LWRDOJ0kc.PzstlYfw7QERTXtJILoWsDqPzmvpneK5Leg";
              public = false;
              require_pkce = true;
              pkce_challenge_method = "S256";
              token_endpoint_auth_method = "client_secret_post";
              authorization_policy = "one_factor";
              userinfo_signed_response_alg = "none";
              consent_mode = "implicit";
              scopes = [ "offline_access" "openid" "email" "picture" "profile" "groups" ];
              response_types = [ "code" ];
              grant_types = [ "authorization_code" ];
              redirect_uris = [ "http://localhost:5002/user/oauth2/authelia/callback" ];
            }
          ];
        };
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d /var/lib/authelia-testing 400 ${user} ${user} -"
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
              displayname: Chris Kruining
              password: $argon2id$v=19$m=65536,t=3,p=4$xl+ILZXFedOXb0Vb/Pao0Q$jfTun8xPYLQNcsjZCcyCeXMzxHAQWOtR7+4BJ+VS6n4
              email: 'chris@kruining.eu'
              picture: 'https://avatars.githubusercontent.com/u/5786905?v=4'
              groups:
                - jellyfin-admins
                - jellyfin-users
                - admin
                - dev

            jacqueline:
              disabled: false
              displayname: Jacqueline Bevers
              password: $argon2id$v=19$m=65536,t=3,p=4$XgN8yEJV+syAE5yeos3HsA$SlN+j/lJfxJ5VxLu2CdrwowlCiWQNNGhIrSyDpohq18
              groups:
              - jellyfin-users

            martijn:
              disabled: false
              displayname: Martijn Kruining
              password: $argon2id$v=19$m=65536,t=3,p=4$XgN8yEJV+syAE5yeos3HsA$SlN+j/lJfxJ5VxLu2CdrwowlCiWQNNGhIrSyDpohq18
              groups:
              - jellyfin-users

            andrea:
              disabled: false
              displayname: Andrea Kruining
              password: $argon2id$v=19$m=65536,t=3,p=4$XgN8yEJV+syAE5yeos3HsA$SlN+j/lJfxJ5VxLu2CdrwowlCiWQNNGhIrSyDpohq18
              groups:
                - jellyfin-users
        '';
      };
    };

    services.caddy = {
      enable = true;
      virtualHosts = {
        "auth.kruining.eu".extraConfig = ''
          reverse_proxy http://127.0.0.1:9091
        '';
      };
      extraConfig = ''
        (auth) {
          forward_auth http://127.0.0.1:9091 {
            uri /api/authz/forward-auth
            copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
          }
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
