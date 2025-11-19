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
    programs.ssh.extraConfig = ''
      Host beheer.hazelhof.nl
        Port 222
        User chris
        AddressFamily inet
        IdentityFile /home/chris/.ssh/id_ed25519
    '';

    services = {
      borgbackup.jobs = {
        media = {
          paths = "/var/media/test";
          encryption.mode = "none";
          # environment.BORG_SSH = "ssh -4 -i /home/chris/.ssh/id_ed25519";
          environment.BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK = "yes";
          repo = "ssh://beheer.hazelhof.nl//media";
          compression = "auto,zstd";
          startAt = "daily";
        };
      };
    };
  };
}
