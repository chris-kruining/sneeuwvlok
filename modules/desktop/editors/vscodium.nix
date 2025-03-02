{ config, options, lib, pkgs, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.desktop.editors.vscodium;
in
{
  options.modules.desktop.editors.vscodium = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "vscodium"; };

  config = mkIf cfg.enable {
    user.packages = attrValues {
      inherit (pkgs) vscodium;
    };
  };
}
