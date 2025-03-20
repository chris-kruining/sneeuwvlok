{ config, lib, pkgs, ... }:
{
  modules = {
    system.audio.enable = true;
    system.bluetooth.enable = true;
  };
}
