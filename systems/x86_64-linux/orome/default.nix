{pkgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  environment.systemPackages = with pkgs; [
    azure-cli
    claude-code
    github-copilot-cli
  ];

  # Firmware updates for the thinkpad through LVFS
  services.fwupd.enable = true;

  sneeuwvlok = {
    hardware.has = {
      bluetooth = true;
      audio = true;
      fingerprint = true;
    };

    desktop.use = "plasma";

    services = {
      authentication.himmelblau = {
        enable = true;
        domains = ["4dotnet.nl"];
        userMap.chris = "c.kruining@4dotnet.nl";
      };
    };

    application = {
      steam.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };

  system.stateVersion = "26.11";
}
