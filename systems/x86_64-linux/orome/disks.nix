{...}: {
  # TODO :: Implement disko at some point

  swapDevices = [];

  boot.supportedFilesystems = ["nfs"];

  # Root lives in a LUKS container, made with `cryptsetup luksFormat --label cryptroot`
  boot.initrd.luks.devices.cryptroot.device = "/dev/disk/by-label/cryptroot";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };
  };
}
