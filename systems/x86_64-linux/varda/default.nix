{ pkgs, lib, ... }:
let
  inherit (lib) mkForce;
in
{
  sneeuwvlok = {
    services = {
      networking.ssh.enable = true;
      media.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };

  boot = {
    supportedFilesystems = mkForce ["btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs"];
  };

  services = {
    qemuGuest.enable = true;
    openssh.settings.PermitRootLogin = mkForce "yes";
  };

  environment.systemPackages = with pkgs; [
    # sbctl
    git
    gum
    (
      writeShellScriptBin "rescue" ''
        #!/usr/bin/env bash
        set -euo pipefail

        gum "device name"

        sudo mkdir -p /mnt/{dev,proc,sys,boot}
        sudo mount -o bind /dev /mnt/dev
        sudo mount -o bind /proc /mnt/proc
        sudo mount -o bind /sys /mnt/sys
        sudo chroot /mnt /nix/var/nix/profiles/system/activate
        sudo chroot /mnt /run/current-system/sw/bin/bash

        sudo mount /dev/vda1 /mnt/boot
        sudo cryptsetup open /dev/vda3 cryptroot
        sudo mount /dev/mapper/cryptroot /mnt/

        sudo nixos-enter
      ''
    )
    (
      writeShellScriptBin "nix_installer"
      ''
        #!/usr/bin/env bash
        set -euo pipefail

        if [ "$(id -u)" -eq 0 ]; then
        	echo "ERROR! $(basename "$0") should be run as a regular user"
        	exit 1
        fi

        if [ ! -d "$HOME/github/sneeuwvlok/.git" ]; then
        	git clone https://github.com/chris-kruining/sneeuwvlok.git "$HOME/github/sneeuwvlok"
        fi

        TARGET_HOST=$(ls -1 ~/github/sneeuwvlok/systems/*/default.nix | cut -d'/' -f6 | grep -v iso | gum choose)

        if [ ! -e "$HOME/github/sneeuwvlok/hosts/$TARGET_HOST/disks.nix" ]; then
        	echo "ERROR! $(basename "$0") could not find the required $HOME/github/sneeuwvlok/hosts/$TARGET_HOST/disks.nix"
        	exit 1
        fi

        gum confirm  --default=false \
        "🔥 🔥 🔥 WARNING!!!! This will ERASE ALL DATA on the disk $TARGET_HOST. Are you sure you want to continue?"

        echo "Partitioning Disks"
        sudo nix run github:nix-community/disko \
        --extra-experimental-features "nix-command flakes" \
        --no-write-lock-file \
        -- \
        --mode zap_create_mount \
        "$HOME/dotfiles/hosts/$TARGET_HOST/disks.nix"

        #echo "Creating blank volume"
        #sudo btrfs subvolume snapshot -r /mnt/ /mnt/root-blank

        #echo "Set up attic binary cache"
        #attic use prod || true

        sudo nixos-install --flake "$HOME/dotfiles#$TARGET_HOST"
      ''
    )
  ];

  system.stateVersion = "23.11";
}
