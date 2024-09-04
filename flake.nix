{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox.url = "github:nix-community/flake-firefox-nightly";

    stylix.url = "github:danth/stylix";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser.url = "github:MarceColl/zen-browser-flake";
  };

  outputs = inputs @ { self, nixpkgs, nixpkgs-unstable, ... }:
  let
    inherit (lib.my) mapModules mapModulesRec mapHosts;
    
    system = "x86_64-linux";

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
  in
  {
    lib = lib.my;

    overlays = {
      default = final: prev: {
        unstable = pkgs-unstable;
        my = self.packages.${system};
      };

#       nvfetcher = final: prev: {
#         sources =
#           builtins.mapAttrs (_: p: p.src)
#           ((import ./packages/_sources/generated.nix) {
#             inherit (final) fetchurl fetchgit fetchFromGitHub dockerTools;
#           });
#       };
    };

#     packages."${system}" = mapModules ./packages (p: pkgs.callPackage p {});

    nixosModules =
      {
        sneeuwvlok = import ./.;
      }
      // mapModulesRec ./modules import;

    nixosConfigurations = mapHosts ./hosts {};

    devShells."${system}".default = import ./shell.nix { inherit lib pkgs; };
  };
}
