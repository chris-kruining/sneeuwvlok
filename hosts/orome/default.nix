{ config, lib, pkgs, ... }:
{
  modules = {
    system.audio.enable = true;
    networking.enable = true;
  };
}
