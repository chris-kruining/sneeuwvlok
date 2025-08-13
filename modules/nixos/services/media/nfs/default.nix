{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.media.nfs;
in
{
  options.${namespace}.services.media.nfs = {
    enable = mkEnableOption "Enable NFS";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 2049 ];

    services.nfs.server = {
      enable = true;
      exports = ''
        /var/media manwe(rw,sync,no_subtree_check,fsid=0)
      '';
    };
  };
}
