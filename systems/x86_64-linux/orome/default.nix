{ ... }:
let
in
{
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  sneeuwvlok = {
    hardware.has = {
      bluetooth = true;
      audio = true;
    };
  };

  system.stateVersion = "23.11";
}