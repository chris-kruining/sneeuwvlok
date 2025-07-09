{ ... }:
{
  boot.loader = {
    efi.canTouchEfiVariables = true;

    # grub = {
    #   enable = true;
    #   efiSupport = cfg.mode == "uefi";
    #   devices = [ "nodev" ];
    #   configurationLimit = 1;
    # };

    systemd-boot.enable = true;

    timeout = 0;
  };

  # nixos-boot = {
  #   enable = true;

  #   bgColor = { red = 17; green = 17; blue = 27; };
  # };

  time.timeZone = "Europe/Amsterdam";
}
