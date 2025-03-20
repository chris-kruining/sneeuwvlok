{ config, options, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.strings) concatStringsSep;
in
{
  options.modules.${user}.shell.toolset.yazi = let
    inherit (lib.options) mkEnableOption;
  in { 
    enable = mkEnableOption "system-monitor"; 
  };

  config = mkIf config.modules.${user}.shell.toolset.yazi.enable {
    home-manager.users.${user}.programs.yazi = {
      enable = true;
    };
  };
}
