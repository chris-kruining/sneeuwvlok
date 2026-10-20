{pkgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware.nix
    ./vpn.nix
  ];

  environment.systemPackages = with pkgs; [
    claude-code
    github-copilot-cli
    openspec

    (azure-cli.withExtensions [azure-cli.extensions.azure-devops])
    awscli2
    bicep
    opentofu
    dapr-cli
    gh
  ];

  # The laserjet, and whatever else is around, without drivers: cups and sane find them on the network (ipp everywhere, escl)
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
  hardware.sane = {
    enable = true;
    extraBackends = [pkgs.sane-airscan];
  };
  users.users.chris.extraGroups = ["scanner" "lp"];

  # DBeaver's connections, converted from pgadmin. The home config puts them in place once, after that dbeaver owns them
  sops.secrets = {
    "dbeaver/data_sources".owner = "chris";
    "dbeaver/credentials".owner = "chris";
  };

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

    hardware.keyboard.voyager.enable = true;

    desktop.use = "plasma";

    system.update = {
      enable = true;
      notify = true;
    };

    services = {
      networking.ssh.enable = true;
      virtualisation.podman.enable = true;
      networking.awsvpnclient.enable = true;

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
