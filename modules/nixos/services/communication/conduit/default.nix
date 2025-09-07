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

    services = {
      matrix-conduit = {
        enable = true;

        settings.global = {
          address = "::1";
          port = 4001;

          database_backend = "rocksdb";

          server_name = "chris-matrix";
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
        virtualHosts = {
          ${domain}.extraConfig = ''
            # import auth-z

            # reverse_proxy http://127.0.0.1:5002
          '';
        };
      };
    };
  };
}
