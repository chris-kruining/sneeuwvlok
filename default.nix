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
#       inputs.nixvim.nixosModules.nixvim
      inputs.stylix.nixosModules.stylix
      (mkAliasOptionModule ["hm"] ["home-manager" "users" config.user.name])
      (mkAliasOptionModule ["home"] ["hm" "home"])
      (mkAliasOptionModule ["create" "configFile"] ["hm" "xdg" "configFile"])
      (mkAliasOptionModule ["create" "dataFile"] ["hm" "xdg" "dataFile"])
    ]
    ++ (mapModulesRec' (toString ./modules) import);

  environment.variables = {
    SNEEUWVLOK = config.sneeuwvlok.dir;
    NIXPKGS_ALLOW_UNFREE = "1";
  };  

  system = {
    stateVersion = "23.11";
    configurationRevision = with inputs; mkIf (self ? rev) self.rev;
  };
}
