{ ... }:
{
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  networking = {
    interfaces.enp2s0 = {
      ipv6.addresses = [
        { address = "2a0d:6e00:1dc9:0::dead:beef"; prefixLength = 64; }
      ];

      useDHCP = true;
    };

    defaultGateway = {
      address = "192.168.1.1";
      interface = "enp2s0";
    };

    defaultGateway6 = {
      address = "fe80::1";
      interface = "enp2s0";
    };
  };

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
