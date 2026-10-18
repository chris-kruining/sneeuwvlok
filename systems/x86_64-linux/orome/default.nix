{pkgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware.nix
    ./vpn.nix
  ];

  environment.systemPackages = with pkgs; [
    azure-cli
    claude-code
    github-copilot-cli
  ];

  # The host key is put in place by the install (see the readme), sops decrypts with it even without sshd running
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  # Firmware updates for the thinkpad through LVFS
  services.fwupd.enable = true;

  sneeuwvlok = {
    hardware.has = {
      bluetooth = true;
      audio = true;
      fingerprint = true;
    };

    desktop.use = "plasma";

    system.update = {
      enable = true;
      notify = true;
    };

    services = {
      networking.ssh.enable = true;

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
