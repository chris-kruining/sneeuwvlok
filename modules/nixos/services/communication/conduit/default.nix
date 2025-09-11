{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.communication.conduit;
  domain = "matrix.kruining.eu";
in
{
  options.${namespace}.services.communication.conduit = {
    enable = mkEnableOption "conduit (Matrix server)";
  };

  config = mkIf cfg.enable {
    # ${namespace}.services = {
    #   persistance.postgresql.enable = true;
    #   virtualisation.podman.enable = true;
    # };

    networking.firewall.allowedTCPPorts = [ 4001 8448 ];

    services = {
      matrix-conduit = {
        enable = true;

        settings.global = {
          address = "::";
          port = 4001;

          server_name = "matrix.kruining.eu";

          database_backend = "rocksdb";
          # database_path = "/var/lib/matrix-conduit/";

          allow_check_for_updates = false;
          allow_registration = false;

          enable_lightning_bolt = false;
        };
      };

      # postgresql = {
      #   enable = true;
      #   ensureDatabases = [ "conduit" ];
      #   ensureUsers = [
      #     {
      #       name = "conduit";
      #       ensureDBOwnership = true;
      #     }
      #   ];
      # };

      caddy = {
        enable = true;
        virtualHosts = let
          inherit (builtins) toJSON;

          server = {
            "m.server" = "${domain}:443";
          };
          client = {
            "m.homeserver".base_url = "https://${domain}";
            "m.identity_server".base_url = "https://auth.amarth.cloud";
          };
        in {
          "${domain}".extraConfig = ''
            header /.well-known/matrix/* Content-Type application/json
            header /.well-known/matrix/* Access-Control-Allow-Origin *
            respond /.well-known/matrix/server `${toJSON server}`
            respond /.well-known/matrix/client `${toJSON client}`

            reverse_proxy /_matrix/* http://::1:4001
            # reverse_proxy /_synapse/client/* http://::1:4001
          '';
        };
      };
    };
  };
}
