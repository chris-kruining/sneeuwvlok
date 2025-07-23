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
    desktop.use = "gamescope";
  };

  system.stateVersion = "23.11";
}