{inputs, ...}: {
  # disko comes with clan-core, which already depends on it
  imports = [inputs.clan-core.inputs.disko.nixosModules.disko];

  swapDevices = [];

  boot.supportedFilesystems = ["nfs"];

  # Dolphin and the system monitor list both the luks partition and the filesystem it opens to, as two drives.
  # The container is of no use there, the filesystem in it is
  services.udev.extraRules = ''
    ENV{ID_PART_ENTRY_NAME}=="disk-main-luks", ENV{UDISKS_IGNORE}="1"
  '';

  # Applied by nixos-anywhere when installing, this wipes the disk, all but the partition windows-f.nix keeps.
  # disko also generates `fileSystems` and the luks device from it
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";

    content = {
      type = "gpt";

      partitions = {
        # 1 GiB because grub copies every kernel generation onto it
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };

        luks = {
          # To the end of the free space instead of the disk: the whole disk when it is empty, up to F: while windows-f.nix keeps it
          end = "0";
          content = {
            type = "luks";
            name = "cryptroot";
            # Only read while formatting, nixos-anywhere copies it there with `--disk-encryption-keys`
            passwordFile = "/tmp/secret.key";
            settings = {
              allowDiscards = true;
              # Unlocked by the tpm once it is enrolled (see the readme), until then and as fallback with the passphrase
              crypttabExtraOpts = ["tpm2-device=auto"];
            };

            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
