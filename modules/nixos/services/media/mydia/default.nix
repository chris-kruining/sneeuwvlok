{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.services.media.mydia;
in {
  options.sneeuwvlok.services.media.mydia = {
    enable = mkEnableOption "Enable Mydia";
  };

  config = mkIf cfg.enable {
    services.mydia = {
      enable = true;

      port = 2010;
      listenAddress = "0.0.0.0";
      openFirewall = true;

      mediaLibraries = [
        "/var/mydia/movies"
        "/var/mydia/series"
      ];

      database = {
        # type = "sqlite";
        # uri = "file:///var/lib/mydia/mydia.db";
        type = "postgres";
        uri = "postgres://mydia@localhost:5432/mydia?sslmode=disable";
        passwordFile = config.sops.templates."mydia/database_password".path;
      };

      secretKeyBaseFile = config.sops.secrets."mydia/secret_key_base".path;
      guardianSecretKeyFile = config.sops.secrets."mydia/guardian_secret".path;

      oidc = {
        enable = true;
        issuer = "https://auth.kruining.eu";
        clientIdFile = config.sops.secrets."mydia/oidc_id".path;
        clientSecretFile = config.sops.secrets."mydia/oidc_secret".path;
        scopes = ["openid" "profile" "email"];
      };

      downloadClients = {
        qbittorrent = {
          type = "qbittorrent";
          host = "localhost";
          port = 2008;
          username = "admin";
          passwordFile = config.sops.secrets."mydia/qbittorrent_password".path;
          useSsl = false;
        };
      };
    };

    sops.secrets = let
      base =
        ["secret_key_base" "guardian_secret" "oidc_id" "oidc_secret"]
        |> lib.map (name:
          lib.nameValuePair "mydia/${name}" {
            owner = config.services.mydia.user;
            group = config.services.mydia.group;
            restartUnits = ["mydia.service"];
          })
        |> lib.listToAttrs;
    in
      base
      // {
        "mydia/qbittorrent_password" = {
          owner = config.services.mydia.user;
          group = config.services.mydia.group;
          restartUnits = ["mydia.service"];
          key = "qbittorrent/password";
        };
      };

    sops.templates."mydia/database_password" = {
      owner = config.services.mydia.user;
      group = config.services.mydia.group;
      restartUnits = ["mydia.service"];
      content = ''
        DATABASE_PASSWORD=""
      '';
    };
  };
}
