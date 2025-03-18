{ inputs, config, options, lib, pkgs, ... }:
let
  inherit (builtins) pathExists toString;
  inherit (lib.lists) findFirst;
  inherit (lib.modules) mkAliasDefinitions;
in
{
  options = let
    inherit (lib.types) attrs path;
    inherit (lib.my) mkOpt;
  in
  {
    user = mkOpt attrs {};
  };

  config = {
    nix.settings = let
      inherit (lib) elem attrNames filterAttrs;

      users = (attrNames (filterAttrs (name: user: elem "wheel" (user.extraGroups or [])) config.users.users));# ++ [ "root" ];
    in
      {
        trusted-users = users;
        allowed-users = users;
      };
  };
}
