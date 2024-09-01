{ config, options, lib, pkgs, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.desktop.editors.zed;
in
{
  options.modules.desktop.editors.zed = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "zed"; };

  config = mkIf cfg.enable {
    user.packages = attrValues {
      inherit (pkgs) zed-editor;
    };
  };
}
