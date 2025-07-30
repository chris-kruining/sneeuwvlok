{ ... }:
{
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  sneeuwvlok = {
    hardware.has = {
      gpu.amd = true;
      bluetooth = true;
      audio = true;
    };

    boot = {
      quiet = true;
      animated = true;
    };

    desktop.use = "plasma";
  };

  system.stateVersion = "23.11";
}
