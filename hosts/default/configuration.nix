{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/boot.nix
    ../../modules/system/audio.nix
    ../../modules/system/zsa_voyager.nix
    
    ../../modules/desktop/plasma.nix



   
    ../../modules/programs/security.nix
    ../../modules/programs/theme.nix
    ../../modules/programs/shell.nix
    ../../modules/programs/gaming.nix
    ../../modules/programs/harden.nix
    ../../modules/programs/communication.nix
    ../../modules/programs/office.nix
    inputs.home-manager.nixosModules.default
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  networking.hostName = "chris-pc";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Enable the X11 windowing system.
  services.xserver.enable = true;


  # Enable sound.
  sound.enable = false;
  hardware.pulseaudio.enable = false;
  users.extraGroups.audio.members = [ "chris" ];
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.chris = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "backup";
    users = {
      chris.imports = [ ../../users/chris.nix ];
#      root.imports = [ ../../users/root.nix ];
    };
  };

  environment.systemPackages = with pkgs; [
    neovim
    wget
#    chromium
    thunderbird
    zoxide
    bottles
    atuin
    btop
    dust
    bat
    tldr
    eza
    nextcloud-client
  ];

  # session variable for chrome/electron wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  systemd.services.numLockOnTty = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = lib.mkForce (pkgs.writeShellScript "numLockOnTty" ''
        for tty in /dev/tty{1..6}; do
          ${pkgs.kbd}/bin/setleds -D +num < "$tty";
        done
      '');
    };
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "23.11"; # Did you read the comment?

}

