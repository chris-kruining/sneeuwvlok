{ config, options, lib, pkgs, ... }:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  cfg = config.modules.shell;
in
{
  options.modules.shell = {};

  config = mkIf cfg.enable {};
}
