{lib, osConfig, ...}: let
  inherit (lib) mkForce;

  # The shared plasma config is made for desktops that never sleep, a laptop that travels has to lock and suspend
  power = {
    whenLaptopLidClosed = mkForce "sleep";
    inhibitLidActionWhenExternalMonitorConnected = true;

    autoSuspend = {
      action = mkForce "sleep";
      idleTimeout = 900;
    };

    turnOffDisplay.idleTimeout = mkForce 600;
  };
in {
  home.stateVersion = osConfig.system.stateVersion;

  programs.git = {
    settings.user = {
      name = "Chris Kruining";
      email = "chris@kruining.eu";
    };
  };

  programs.plasma = {
    kscreenlocker = {
      autoLock = mkForce true;
      lockOnResume = mkForce true;
      timeout = 10;
    };

    powerdevil = {
      AC = power;
      battery = power;
      lowBattery = power;
    };
  };

  sneeuwvlok = {
    defaults = {
      shell = "zsh";
      terminal = "ghostty";
      browser = "helium";
      editor = "zed";
    };

    shell = {
      corePkgs.enable = true;
    };

    themes = {
      enable = true;
      theme = "everforest";
      polarity = "dark";
    };

    development = {
      rust.enable = true;
      javascript.enable = true;
      dotnet.enable = true;
    };

    application = {
      bitwarden.enable = true;
      helium.enable = true;
      onlyoffice.enable = true;
      signal.enable = true;
    };

    shell.zsh.enable = true;
    terminal.ghostty.enable = true;

    editor = {
      zed.enable = true;
      nano.enable = true;
    };
  };
}
