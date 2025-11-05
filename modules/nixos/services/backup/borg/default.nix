{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.backup.borg;
in
{
  options.${namespace}.services.backup.borg = {
    enable = mkEnableOption "Borg Backup";
  };

  config = mkIf cfg.enable {
    services = {
      borgbackup.jobs = {
        media = {
          paths = "/var/media/test";
          encryption.mode = "none";
          environment.BORG_SSH = "ssh -i /home/chris/.ssh/id_ed25519 -4";
          repo = "ssh://chris@beheer.hazelhof.nl:222/media";
          compression = "auto,zstd";
          startAt = "daily";
        };
      };
    };
  };
}
