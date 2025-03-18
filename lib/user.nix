{ lib, ... }: let
  inherit (builtins) baseNameOf;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.strings) removeSuffix;
in rec
{
  mkSysUser = path: let
    user = {
      full_name = "TODO";
      is_trusted = true;
    };
    name = removeSuffix ".nix" (baseNameOf path);
  in
    {
      inherit name;
      description = user.full_name;
      extraGroups = (user.groups or []) ++ (if user.is_trusted then [ "wheel" ] else []);
      isNormalUser = true;
      initialPassword = "kaas";
      home = "/home/${name}";
      group = "users";
    };

  mkHmUser = path: stateVersion: let
    # user = import path {};
    name = removeSuffix ".nix" (baseNameOf path);
  in
    {
      home = {
        inherit stateVersion;
        sessionPath = [ "$SNEEUWVLOK_BIN" "$XDG_BIN_HOME" "$PATH" ]; # Pretty sure I don't need this.
      };
    };
}
