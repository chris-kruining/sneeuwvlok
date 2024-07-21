{ pkgs, config, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.programs = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Rust developmnt";
  };

  config = mkIf conf.modules.programs.enable {

  };
}
