{ config, pkgs, ... }:
{
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # Nvidia
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    
    powerManagement = {
      enable = true;
      finegrained = false;
    };

    #prime = {
    #  sync.enable = true;

      # Integrated
      # interBusId = "PCI:0:0:0";

      # Dedicated
    #  nvidiaBusId = "PCI:2:0:0";
    #};
  };

  # Steam
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    #mangohud
    protonup
  ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/home/chris/.steam/root/compatibilitytools.d";
  };

  programs.gamemode.enable = true;
}
