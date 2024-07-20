{ pkgs, ... }:
{
  networking = {
    hostName = "chris-pc";
    networkmanager.enable = true;
  };
}
