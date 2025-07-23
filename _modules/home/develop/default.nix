{ config, lib, user, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.${user}.develop = let
    inherit (lib.options) mkEnableOption;
  in
  {
    xdg.enable = mkEnableOption "XDG-related conf" // { default = true; };
  };

  config = mkIf config.modules.${user}.develop.xdg.enable {

  };
}
