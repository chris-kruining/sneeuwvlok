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
      gpu.nvidia = true;
      audio = true;
    };

    boot = {
      quiet = true;
      animated = true;
    };

    desktop.use = "gamescope";
  };

  system.stateVersion = "23.11";
}