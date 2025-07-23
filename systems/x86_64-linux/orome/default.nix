{ ... }:
let
in
{
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  sneeuwvlok = {
    preset = "desktop";

    bluetooth.enable = true;
  };

  system.stateVersion = "23.11";
}