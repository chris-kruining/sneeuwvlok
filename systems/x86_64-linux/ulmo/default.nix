{ ... }:
{
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  sneeuwvlok = {
    services = {
      authentication.authelia.enable = true;
      authentication.zitadel.enable = true;

      communication.matrix.enable = true;

      development.forgejo.enable = true;

      networking.ssh.enable = true;

      media.enable = true;
      media.homer.enable = true;
      media.nfs.enable = true;

      observability = {
        grafana.enable = true;
        prometheus.enable = true;
        loki.enable = true;
        promtail.enable = true;
      };

      security.vaultwarden.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };

  system.stateVersion = "23.11";
}
