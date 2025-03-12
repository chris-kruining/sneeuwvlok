{ inputs, config, lib, pkgs, ... }:
let
  inherit (builtins) toString;
  inherit (lib.modules) mkAliasOptionModule mkIf;
  inherit (lib.my) mapModulesRec' mapModules mkSysUser mkHmUser;
in
{
  imports = [
      inputs.home-manager.nixosModules.home-manager
      inputs.nvf.nixosModules.default
      inputs.stylix.nixosModules.stylix
      inputs.nix-minecraft.nixosModules.minecraft-servers
      inputs.sops-nix.nixosModules.sops
      (mkAliasOptionModule ["hm"] ["home-manager" "users" config.user.name])
      (mkAliasOptionModule ["home"] ["hm" "home"])
    ]
    ++ (mapModulesRec' (toString ./modules) import);

  nixpkgs.overlays = [
    inputs.nix-minecraft.overlay
    inputs.flux.overlays.default
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.variables = {
    SNEEUWVLOK = config.sneeuwvlok.dir;
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yml;
    defaultSopsFormat = "yml";

    age.keyFile = "/home/";
  };
}
