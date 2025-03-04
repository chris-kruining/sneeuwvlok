{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.services.auth = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Auth";
  };

  config = mkIf config.modules.services.auth.enable {
    environment.systemPackages = with pkgs; [
      authelia
    ];

    services.authelia.instances.testing = {
      enable = true;
      secrets.storageEncryptionKeyFile = "/etc/authelia/storageEncryptionKeyFile";
      secrets.jwtSecretFile = "/etc/authelia/jwtSecretFile";
      settings = {
        log.level = "info";
        authentication_backend.file.path = "/etc/authelia/users_database.yml";
        access_control.default_policy = "one_factor";
        session.domain = "kruining.eu";
        storage.local.path = "/tmp/db.sqlite3";
        notifier.filesystem.filename = "/tmp/notifications.txt";
        server.endpoints.authz.forward-auth.implementation = "ForwardAuth";
        identity_providers.oidc.clients = [];
      };
    };

    # systemd.services."authelia-testing" = {
    #   serviceConfig.Environment = "X_AUTHELIA_CONFIG_FILTERS=template";
    # };

    # These should not be set from nix but through other means to not leak the secret!
    # This is purely for testing purposes!
    environment.etc."authelia/storageEncryptionKeyFile" = {
      mode = "0400";
      user = "authelia-testing";
      text = "you_must_generate_a_random_string_of_more_than_twenty_chars_and_configure_this";
    };
    environment.etc."authelia/jwtSecretFile" = {
      mode = "0400";
      user = "authelia-testing";
      text = "a_very_important_secret";
    };
    environment.etc."authelia/users_database.yml" = {
      mode = "0400";
      user = "authelia-testing";
      text = ''
        users:
          bob:
            disabled: false
            displayname: bob
            # password of password
            password: $argon2id$v=19$m=65536,t=3,p=4$2ohUAfh9yetl+utr4tLcCQ$AsXx0VlwjvNnCsa70u4HKZvFkC8Gwajr2pHGKcND/xs
            email: bob@jim.com
            groups:
              - admin
              - dev
      '';
    };

    services.caddy = {
      enable = true;
      virtualHosts = {
        "auth.kruining.eu".extraConfig = ''
          reverse_proxy :9091
        '';
        "kaas.kruining.eu".extraConfig = ''
          respond "KAAS"
        '';
      };
      extraConfig = ''
        (auth) {
          forward_auth :9091 {
            uri /api/authz/forward-auth
            copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
          }
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
