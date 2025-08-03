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

    application = {
      steam.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };


  services.displayManager.autoLogin = {
    enable = true;
    user = "chris";
  };

  system.stateVersion = "23.11";
}
