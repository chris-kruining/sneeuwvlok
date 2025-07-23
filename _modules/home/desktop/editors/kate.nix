{ config, options, lib, pkgs, user, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;

  cfg = config.modules.${user}.desktop.editors.kate;
in
{
  options.modules.${user}.desktop.editors.kate = let
    inherit (lib.options) mkEnableOption;
  in { 
    enable = mkEnableOption "kate"; 
    };

  config = mkIf cfg.enable {
    home-manager.users.${user}.programs.kate.enable = true;
  };
}
