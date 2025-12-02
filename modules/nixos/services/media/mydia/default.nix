{
  config,
  lib,
  namespace,
  inputs,
  system,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.media.mydia;
in {
  imports = [
    inputs.mydia.nixosModules.default
  ];

  options.${namespace}.services.media.mydia = {
    enable = mkEnableOption "Enable Mydia";
  };

  config = mkIf cfg.enable {
    services.mydia = {
      enable = true;

      port = 2010;
      listenAddress = "0.0.0.0";
      openFirewall = true;

      database = {
        type = "postgres";
        uri = "postgres://localhost:5432/mydia?sslMode=disable";
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
    };

    sops.secrets =
      ["secret_key_base" "guardian_secret" "oidc_id" "oidc_secret"]
      |> lib.map (name:
        lib.nameValuePair "mydia/${name}" {
          owner = config.services.mydia.user;
          group = config.services.mydia.group;
          restartUnits = ["mydia.service"];
        })
      |> lib.listToAttrs;
  };
}
