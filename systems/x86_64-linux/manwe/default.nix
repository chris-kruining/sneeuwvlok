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

    hardware.has = {
      gpu.amd = true;
      bluetooth = true;
    };
  };

  system.stateVersion = "23.11";
}