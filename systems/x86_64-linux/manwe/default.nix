{ pkgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  system.activationScripts.remove-gtkrc.text = "rm -f /home/chris/.gtkrc-2.0";

  services.logrotate.checkConfig = false;

  environment.systemPackages = with pkgs; [ beyond-all-reason openrct2 ];

  sneeuwvlok = {
    services.networking.ssh.enable = true;

    # Wakes up after ulmo's nightly build, updates and goes back to sleep
    system.update = {
      enable = true;
      operation = "switch";
      wake = true;
    };

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
