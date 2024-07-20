{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";
  };

  outputs = { self, nixpkgs, ... }@inputs: let
    inherit (lib.my) mapModules mapModules mapHosts;

    mkPkgs = pkgs: extraOverlays:
      import pkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = extraOverlays ++ (lib.attrValues self.overlays);
      };
    pkgs = mkPkgs nixpkgs [self.overlays.default];
    pkgs-unstable = mkPkgs nixpkgs-unstable [];

    lib = nixpkgs.lib.extend (final: prev: {
      my = import ./lib {
        inherit pkgs inputs;
        
        lib = final;
      };
    });
  in {
    lib = lib.my;

    packages."${system}" = mapModules ./paclages (p: pkgs.callPackage p {});

    nixosModules =
      {
        chris = import ./.;
      }
      // mapModulesRec ./modules import;

    nixosConfigurations = mapHosts ./hosts {};

    devShells."${system}".default = import ./shell.nix { inherit lib pkgs; };



#    nixosConfigurations = {
#      pc = nixpkgs.lib.nixosSystem {
#        specialArgs = {inherit inputs;};
#        modules = [
#          ./hosts/pc/default.nix
#          inputs.home-manager.nixosModules.default
#          inputs.stylix.nixosModules.stylix
#        ];
#      };
#    };


    
  };
}
