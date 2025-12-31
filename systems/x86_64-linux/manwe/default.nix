{...}: {
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  system.activationScripts.remove-gtkrc.text = "rm -f /home/chris/.gtkrc-2.0";

  services.logrotate.checkConfig = false;

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

    desktop.use = "cosmic";

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
