{ config, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.modules.networking.nfs;
in
{
  options.modules.networking.nfs = {
    enable = mkEnableOption "Enable NFS";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 2049 ];

    services.nsf.server = {
      enable = true;
      exports = ''
        /var/media  manwe(rw,fsid=0,no_subtree_check)
      '';
    };
  };
}
