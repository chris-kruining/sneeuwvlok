{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./disks.nix
    ./hardware.nix
    ./vpn.nix
  ];

  environment.systemPackages = with pkgs; [
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

  # Helium's extensions, from the web store on its first start and still removable. Their settings and the open tabs come over from windows, see the readme
  programs.chromium.extraOpts.ExtensionSettings = lib.genAttrs [
    "hlepfoohegkhhmjieoechaddaejaokhf" # Refined GitHub
    "idgpnmonknjnojddfkpgkljpfnnfcklj" # ModHeader
    "kmcfjchnmmaeeagadbhoofajiopoceel" # Solid Devtools
    "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock
    "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
  ] (_: {
    installation_mode = "normal_installed";
    update_url = "https://clients2.google.com/service/update2/crx";
  });

  # The only one of them with managed storage: bitwarden straight to my own vault
  programs.chromium.extraOpts."3rdparty".extensions.nngceckbapebfimnlniiiahkandclblb.environment.base = "https://vault.kruining.eu";

  # DBeaver's connections, converted from pgadmin. The home config puts them in place once, after that dbeaver owns them
  sops.secrets = {
    "dbeaver/data_sources".owner = "chris";
    "dbeaver/credentials".owner = "chris";

    # The aws profiles and sso session, in secrets because they name menicon's accounts. The home config links it to ~/.aws/config
    "aws/config".owner = "chris";

    # Helium's profile from windows (extension settings, open tabs), a one off, see the readme. Only there until orome is moved over
    "helium/profile" = lib.mkIf (builtins.pathExists ./helium-profile.sops) {
      format = "binary";
      sopsFile = ./helium-profile.sops;
      owner = "chris";
    };
  };

  # The host key is put in place by the install (see the readme), sops decrypts with it even without sshd running
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  # Firmware updates for the thinkpad through LVFS
  services.fwupd.enable = true;

  time.timeZone = "Europe/Amsterdam";

  # English, with dutch dates, units, paper and money
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "nl_NL.UTF-8";
      LC_MEASUREMENT = "nl_NL.UTF-8";
      LC_PAPER = "nl_NL.UTF-8";
      LC_MONETARY = "nl_NL.UTF-8";
    };
  };
  services.xserver.xkb.layout = "us";

  # No swap partition, compressed swap in memory keeps big builds from running out of it
  zramSwap.enable = true;

  # Docks and other thunderbolt devices have to be authorized, bolt does that and plasma has a page for it
  services.hardware.bolt.enable = true;

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
