{ ... }:
{
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  sneeuwvlok = {
    services.networking.ssh.enable = true;

    # Wakes up after ulmo's nightly build, updates and goes back to sleep
    system.update = {
      enable = true;
      operation = "switch";
      wake = true;
    };

    hardware.has = {
      gpu.nvidia = true;
      audio = true;
    };

    boot = {
      quiet = true;
      animated = true;
    };

    desktop.use = "gamescope";

    application = {
      steam.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };

  system.stateVersion = "23.11";
}
