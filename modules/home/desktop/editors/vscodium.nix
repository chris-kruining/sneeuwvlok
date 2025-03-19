{ config, options, lib, pkgs, user, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.${user}.desktop.editors.vscodium;
in
{
  options.modules.${user}.desktop.editors.vscodium = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "vscodium"; };

  config = mkIf cfg.enable {
    home-manager.users.${user}.home.packages = attrValues {
      inherit (pkgs) vscodium;
    };
  };
}
