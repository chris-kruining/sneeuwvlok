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

      networking.ssh.enable = true;

      media.enable = true;
      media.nfs.enable = true;

      development.forgejo.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };

  system.stateVersion = "23.11";
}
