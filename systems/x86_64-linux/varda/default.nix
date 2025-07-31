{ pkgs, ... }:
{
  imports = [
    "${pkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix"
    "${pkgs}/nixos/modules/installer/cd-dvd/channel.nix"
  ];

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
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = lib.mkForce ["btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs"];
  };

  services = {
    qemuGuest.enable = true;
    openssh.settings.PermitRootLogin = "yes";
  };

  system.stateVersion = "23.11";
}
