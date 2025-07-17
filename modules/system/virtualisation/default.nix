{ config, options, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkEnableOption;
in
{
  options.modules.virtualisation = {};
}
