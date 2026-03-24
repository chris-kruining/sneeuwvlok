{pkgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  environment.systemPackages = with pkgs; [
    azure-cli
    github-copilot-cli
  ];

  sneeuwvlok = {
    hardware.has = {
      bluetooth = true;
      audio = true;
    };

    services.authentication.himmelblau.enable = true;

    application = {
      steam.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };

  system.stateVersion = "23.11";
}
