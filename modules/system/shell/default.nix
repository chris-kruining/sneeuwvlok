{ config, options, lib, pkgs, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf;

  cfg = config.modules.shell;
in
{
  options.modules.shell = let
    inherit (lib.options) mkEnableOption;
  in
  {};

  config = mkIf cfg.enable {};
}
