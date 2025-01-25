{ config, options, lib, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;

  time.timeZone = "Europe/Amsterdam";
}
