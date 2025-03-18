{ inputs, config, lib, pkgs, ... }:
let
  inherit (builtins) toString;
  inherit (lib.modules) mkAliasOptionModule mkIf;
  inherit (lib.my) mapModulesRec' mapModules mkSysUser mkHmUser;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  config = {
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    environment.variables = {
      NIXPKGS_ALLOW_UNFREE = "1";
    };

    sops = {
      defaultSopsFile = ./secrets/secrets.yml;
      defaultSopsFormat = "yml";

      age.keyFile = "/home/";
    };
  };
}
