{ pkgs, lib, ... }:
let
  inherit (lib) mkForce;
in
{
  boot = {
    supportedFilesystems = mkForce ["btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs"];

    loader.efi.canTouchEfiVariables = true;
  };

  networking = {
    wireless.enable = mkForce false;
    networkmanager.enable = true;
  };

  nix = {
    enable = true;
    extraOptions = "experimental-features = nix-command flakes";
    channel.enable = false;

    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      allowed-users = [ "@wheel" ];
      trusted-users = [ "@wheel" ];

      auto-optimise-store = true;
      connect-timeout = 5;
      http-connections = 50;
      log-lines = 50; # more log lines in case of error
      min-free = 1 * (1024 * 1024 * 1024); # GiB # start garbage collector
      max-free = 50 * (1024 * 1024 * 1024); # GiB # until
      warn-dirty = false;
    };
  };

  services = {
    qemuGuest.enable = true;
    openssh = {
      enable = true;
      settings.PermitRootLogin = mkForce "yes";
    };
  };

  users.users.nixos = {
    initialPassword = "kaas";
    initialHashedPassword = mkForce null;
    extraGroups = [ "networkmanager" ];
  };

  environment.systemPackages = with pkgs; [
    # sbctl
    git
    # gum
    # (
    #   writeShellScriptBin "rescue" ''
    #     #!/usr/bin/env bash
    #     set -euo pipefail

    #     gum "device name"

    #     sudo mkdir -p /mnt/{dev,proc,sys,boot}
    #     sudo mount -o bind /dev /mnt/dev
    #     sudo mount -o bind /proc /mnt/proc
    #     sudo mount -o bind /sys /mnt/sys
    #     sudo chroot /mnt /nix/var/nix/profiles/system/activate
    #     sudo chroot /mnt /run/current-system/sw/bin/bash

    #     sudo mount /dev/vda1 /mnt/boot
    #     sudo cryptsetup open /dev/vda3 cryptroot
    #     sudo mount /dev/mapper/cryptroot /mnt/

    #     sudo nixos-enter
    #   ''
    # )
    # (
    #   writeShellScriptBin "nix_installer"
    #   ''
    #     #!/usr/bin/env bash
    #     set -euo pipefail

    #     if [ "$(id -u)" -eq 0 ]; then
    #     	echo "ERROR! $(basename "$0") should be run as a regular user"
    #     	exit 1
    #     fi

    #     if [ ! -d "$HOME/github/sneeuwvlok/.git" ]; then
    #     	git clone https://github.com/chris-kruining/sneeuwvlok.git "$HOME/github/sneeuwvlok"
    #     fi

    #     TARGET_HOST=$(ls -1 ~/github/sneeuwvlok/systems/*/default.nix | cut -d'/' -f6 | grep -v iso | gum choose)

    #     if [ ! -e "$HOME/github/sneeuwvlok/hosts/$TARGET_HOST/disks.nix" ]; then
    #     	echo "ERROR! $(basename "$0") could not find the required $HOME/github/sneeuwvlok/hosts/$TARGET_HOST/disks.nix"
    #     	exit 1
    #     fi

    #     gum confirm  --default=false \
    #     "🔥 🔥 🔥 WARNING!!!! This will ERASE ALL DATA on the disk $TARGET_HOST. Are you sure you want to continue?"

    #     echo "Partitioning Disks"
    #     sudo nix run github:nix-community/disko \
    #     --extra-experimental-features "nix-command flakes" \
    #     --no-write-lock-file \
    #     -- \
    #     --mode zap_create_mount \
    #     "$HOME/dotfiles/hosts/$TARGET_HOST/disks.nix"

    #     #echo "Creating blank volume"
    #     #sudo btrfs subvolume snapshot -r /mnt/ /mnt/root-blank

    #     #echo "Set up attic binary cache"
    #     #attic use prod || true

    #     sudo nixos-install --flake "$HOME/dotfiles#$TARGET_HOST"
    #   ''
    # )
  ];

  system.stateVersion = "23.11";
}
