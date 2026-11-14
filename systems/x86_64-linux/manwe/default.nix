{ pkgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  services.logrotate.checkConfig = false;

  environment.systemPackages = with pkgs; [ beyond-all-reason openrct2 claude-code ];

  # Resolves .local names, the installer among them (installer.local)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # Wake on lan, its mac is 9c:6b:00:9f:54:f2
  networking.interfaces.enp12s0.wakeOnLan.enable = true;

  sneeuwvlok = {
    services.networking.ssh.enable = true;

    # Builds the dependencies of ulmo's pipelines, ulmo wakes it for that
    services.development.ci-deps.builderFor = ["ulmo"];

    # Local models for coding agents, crush on orome reaches it over the network
    services.development.llama-cpp = {
      enable = true;
      models = ["unsloth/Qwen3.6-35B-A3B-GGUF:UD-IQ4_XS"];
      openFirewall = true;
    };

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
