{inputs, ...}: {
  # disko comes with clan-core, which already depends on it
  imports = [inputs.clan-core.inputs.disko.nixosModules.disko];

  swapDevices = [];

  boot.supportedFilesystems = ["nfs"];

  # Applied by nixos-anywhere when installing, this wipes the disk.
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
          size = "100%";
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
