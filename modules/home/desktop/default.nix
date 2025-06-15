{ lib, user, ... }:
let
  inherit (lib.types) either str;
  inherit (lib.my) mkOpt;
in
{
  options.modules.${user}.desktop = {
    type = mkOpt (either str null) "wayland";
  };
}
