{}:
{
  boot.loader.systemd-boot-enable = true;
  
  fileSystems."/home/chris/new_games" = {
    device = "/dev/disk/by-label/games";
    fsType = "ext4";
  };

  fileSystems."/home/chris/data" = {
    device = "/dev/disk/by-label/Data";
    fsType = "ntfs-3g";
    options = [ "rw" "uid=chris" ];
  };
}
