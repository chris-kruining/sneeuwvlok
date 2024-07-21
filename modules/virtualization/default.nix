{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.virtualization = let
    inherit (lib.options) mkEnableOption;
  in
  {
    enable = mkEnableOption "enable virtualization";
  };
}
