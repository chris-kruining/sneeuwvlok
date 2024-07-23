{ config, options, lib, pkgs, ... }:
let
  inherit (builtins) isAttrs;
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.my) anyAttrs countAttrs value;

  cfg = config.modules.desktop;
in
{
  options.modules.desktop = let
    inherit (lib.types) either str;
    inherit (lib.my) mkOpt;
  in {
    type = mkOpt (either str null) null;
  };
}
