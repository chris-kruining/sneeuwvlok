{
  lib,
  pkgs,
  config,
  modulesPath,
  ...
}: let
  inherit (lib) mkForce concatStringsSep;

  # Wifi and ethernet firmware of the common laptop chips (intel, realtek, mediatek, qualcomm) instead of all of linux-firmware.
  # Of intel's only the newest version of every chip, a recent kernel loads that one
  firmware = pkgs.runCommand "installer-firmware" {} ''
    mkdir -p $out/lib/firmware
    cd ${pkgs.linux-firmware}/lib/firmware

    # The files are zstd compressed (.ucode.zst)
    shopt -s nullglob
    for chip in $(for file in iwlwifi-{9000,9260,cc,Qu,QuZ,so,ty,ma,gl,bz,sc}-*.ucode*; do echo "''${file%-*.ucode*}"; done | sort -u); do
      cp -L "$(printf '%s\n' "$chip"-*.ucode* | sort -V | tail -1)" $out/lib/firmware/
    done
    for file in iwlwifi-*.pnvm*; do
      cp -L "$file" $out/lib/firmware/
    done

    for path in rtw88 rtw89 rtlwifi rtl_nic mediatek/mt79* mediatek/WIFI_* ath11k/WCN6855 ath12k/WCN7850 regulatory.db*; do
      cp -rL --no-preserve=mode --parents "$path" $out/lib/firmware/
    done
  '';

  ukify = "${pkgs.systemdUkify}/bin/ukify";
  stub = "${pkgs.systemdUkify}/lib/systemd/boot/efi/linuxx64.efi.stub";
in {
  # Everything, nix store included, is in the initrd: once started there is nothing left to find, which is what trips ventoy up
  imports = ["${modulesPath}/installer/netboot/netboot-minimal.nix"];

  networking.hostName = "installer";

  # Root trusts the personal key, nixos-anywhere connects with it straight away: `nixos-anywhere --target-host root@installer.local`
  sneeuwvlok.services.networking.ssh.enable = true;

  # So it is reachable as installer.local without looking up its address
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # Ethernet just works, wifi through nmtui
  networking.wireless.enable = mkForce false;

  hardware.enableRedistributableFirmware = mkForce false;
  hardware.firmware = mkForce [firmware];

  documentation.enable = mkForce false;
  documentation.man.enable = mkForce false;

  # nixos-anywhere brings what it installs, nothing here needs nixpkgs' source (the flake registry pulls in 200 MB of it)
  nixpkgs.flake = {
    setFlakeRegistry = false;
    setNixPath = false;
  };
  # Snowfall puts nixpkgs and this flake in the registry itself
  nix.registry = mkForce {};
  system.installer.channel.enable = false;

  # nixos-anywhere runs nixos-install here, nixos-rebuild (python) it doesn't need
  system.tools.nixos-rebuild.enable = false;

  # The filesystems my machines use. zfs brings python, xfs and bcachefs their own tools
  boot.supportedFilesystems = mkForce ["ext4" "vfat" "btrfs" "ntfs"];

  programs.git.enable = mkForce false;
  networking.modemmanager.enable = false;

  # The addresses and the host key, on the console, to check that ssh reaches this machine
  services.getty.helpLine = mkForce ''

    Install with nixos-anywhere from another machine: root@installer.local or root@\4 (ssh key only).
    Wifi: nmtui. The host key fingerprint is below.
  '';
  systemd.services.installer-issue = {
    description = "Show the ssh host key fingerprint on the console";
    wantedBy = ["multi-user.target"];
    after = ["sshd.service"];
    before = ["getty.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /run/issue.d
      ${pkgs.openssh}/bin/ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub > /run/issue.d/50-ssh-host-key.issue
    '';
  };

  # Its seed goes on the esp, the installer has none
  systemd.services.systemd-boot-random-seed.enable = false;

  # A single efi file to boot from ventoy, a usb stick or the esp
  system.build.installerEfi = pkgs.runCommand "installer.efi" {} ''
    ${ukify} build \
      --stub ${stub} \
      --linux ${config.system.build.kernel}/${config.system.boot.loader.kernelFile} \
      --initrd ${config.system.build.netbootRamdisk}/initrd \
      --cmdline "init=${config.system.build.toplevel}/init ${concatStringsSep " " config.boot.kernelParams}" \
      --os-release @${config.environment.etc."os-release".source} \
      --output $out
  '';

  system.stateVersion = "26.11";
}
