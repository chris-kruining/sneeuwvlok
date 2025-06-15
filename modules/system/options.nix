{ config, lib, ... }:
let
  inherit (lib.types) attrs;
  inherit (lib.my) mkOpt;
in
{
  options = {
    user = mkOpt attrs {};
  };

  config = {
    environment.variables = {
      NIXPKGS_ALLOW_UNFREE = "1";
    };

    nix.settings = let
      inherit (lib) elem attrNames filterAttrs;

      users = (attrNames (filterAttrs (name: user: elem "wheel" (user.extraGroups or [])) config.users.users));# ++ [ "root" ];
    in
      {
        trusted-users = users;
        allowed-users = users;
        experimental-features = [ "nix-command" "flakes" ];
      };
  };
}
