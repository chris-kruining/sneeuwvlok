{
  lib,
  pkgs,
  config,
  modulesPath,
  namespace,
  ...
}: let
  inherit (lib) mkForce concatStringsSep;

  missionControl = pkgs.${namespace}.mission-control;

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

  # So it is reachable as installer.local without looking up its address. A second installer on the network becomes
  # installer-2.local, the ssh service is how `just machine install` finds them all
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
    extraServiceFiles.ssh = "${pkgs.avahi}/etc/avahi/services/ssh.service";
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

  # The old plain-text banner (getty.helpLine + a oneshot writing the ssh
  # fingerprint to /run/issue.d) is replaced by the mission-control TUI
  # below, which shows all of that live instead of as a static pre-login
  # blurb - so there's nothing useful left for agetty to print up front.
  services.getty.helpLine = mkForce "";

  environment.systemPackages = [missionControl];

  # Launch the dashboard automatically when a *local* login shell starts -
  # this is what makes it appear the moment the auto-logged-in "nixos" user
  # hits the console. Quitting it (q / ctrl+c) just exits the program, and
  # since it's invoked as a plain foreground command here, the login shell
  # that launched it simply continues on to its own prompt afterwards - no
  # exit-code handling needed.
  #
  # Guarded to never fire over ssh: nixos-anywhere drives this machine as
  # root over ssh, and it must always get a plain, uninterrupted shell -
  # this is a local-console-only nicety and must never get in its way.
  programs.bash.loginShellInit = ''
    if [ -z "''${SSH_CONNECTION:-}" ] && [ -z "''${SSH_TTY:-}" ] && [ -t 0 ]; then
      ${missionControl}/bin/mission-control
    fi
  '';

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
