{ ... }:
{
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  sneeuwvlok = {
    services.networking.ssh.enable = true;

    system.update = {
      enable = true;
      notify = true;
    };

    hardware.has = {
      gpu.amd = true;
      bluetooth = true;
      audio = true;
    };

    boot.splash.enable = true;

    desktop.use = "gamescope";

    application = {
      steam.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };

  # NetworkManager does dhcp. Facter turns dhcpcd on for the wifi it saw, which then fights NetworkManager over it
  networking.dhcpcd.enable = false;

  # Loading amdgpu takes ~5s of CPU on this kernel, in the initrd that holds up mounting the root. The splash starts on
  # the firmware's framebuffer and moves over to amdgpu once it's up
  hardware.amdgpu.initrd.enable = false;
  hardware.facter.detected.boot.graphics.kernelModules = [];
  jovian.hardware.amd.gpu.enableEarlyModesetting = false;

  # Its fan curve needs the steamdeck-hwmon driver from Valve's kernel, on the mainline kernel the firmware keeps the fan
  jovian.devices.steamdeck.enableOsFanControl = false;

  system.stateVersion = "23.11";
}
