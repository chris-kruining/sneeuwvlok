{ lib, ... }: let
  inherit (builtins) baseNameOf;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.strings) removeSuffix;
  inherit (lib.my) mapModulesRec';
in rec
{
  mkSysUser = path: let
    name = removeSuffix ".nix" (baseNameOf path);
  in
    {
      inherit name;
      isNormalUser = true;
      initialPassword = "kaas";
      home = "/home/${name}";
      group = "users";
    };

  mkHmUser = path: {stateVersion, ...}:
  {
    home = {
      inherit stateVersion;
      sessionPath = [ "$XDG_BIN_HOME" "$PATH" ]; # Pretty sure I don't need this.
    };
  };
}
