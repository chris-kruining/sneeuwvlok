{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.programs = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Rust developmnt";
  };

  config = mkIf config.modules.programs.enable {

  };
}
