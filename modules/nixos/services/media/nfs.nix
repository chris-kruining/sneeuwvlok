{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.services.media.nfs;
in {
  options.sneeuwvlok.services.media.nfs = {
    enable = mkEnableOption "Enable NFS";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [2049];

    services.nfs.server = {
      enable = true;
      exports = ''
        /var/media manwe(rw,sync,no_subtree_check,fsid=0)
      '';
    };
  };
}
