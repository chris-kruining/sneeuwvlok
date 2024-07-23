{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.virtualisation = let
    inherit (lib.options) mkEnableOption;
  in
  {
    enable = mkEnableOption "enable virtualisation";
  };
}
