{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.services = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Enable all services";
  };
}
