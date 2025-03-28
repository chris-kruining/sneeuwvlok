{ config, lib, pkgs, user, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.my) mkWinApp;

  cfg = config.modules.${user}.desktop.applications.studio;
in
{
  options.${user}.desktop.applications.studio = {};

  config = mkIf cfg.enable {

  };
}
