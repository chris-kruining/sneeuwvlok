{ config, lib, ... }:
let
  inherit (lib.modules) mkIf;

  cfg = config.modules.shell;
in
{
  options.modules.shell = {};

  config = mkIf cfg.enable {};
}
