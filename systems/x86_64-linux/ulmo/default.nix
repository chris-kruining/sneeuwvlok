{ ... }:
let
in
{
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  sneeuwvlok = {
    services = {
      networking.ssh.enable = true;
      media.enable = true;
    };
  };

  system.stateVersion = "23.11";
}