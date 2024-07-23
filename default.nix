{ inputs, config, lib, pkgs, ... }:
let
  inherit (builtins) toString;
  inherit (lib.attrsets) attrValues filterAttrs mapAttrs mapAttrsToList;
  inherit (lib.modules) mkAliasOptionModule mkDefault mkIf;
  inherit (lib.my) mapModulesRec';
in
{
  imports = [
      inputs.home-manager.nixosModules.home-manager
      inputs.stylix.nixosModules.stylix
      (mkAliasOptionModule ["hm"] ["home-manager" "users" config.user.name])
    ]
    ++ (mapModulesRec' (toString ./modules) import);

  environments.variables = {
    KAAS = config.kaas.dir;
    KAAS_BIN = config.kaasbinDir;
    NIXPKGS_ALLOW_UNFREE = "1";
  };  

  system = {
    stateVersion = "23.11";
    configurationRevision = with inputs; mkIf (self ? rev) self.rev;
  };
}
