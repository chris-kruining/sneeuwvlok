{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox.url = "github:nix-community/flake-firefox-nightly";

    stylix.url = "github:danth/stylix";

    rust.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs @ { self, nixpkgs, nixpkgs-unstable, ... }:
  let
    inherit (lib.my) mapModules mapModulesRec mapHosts;
    
    system = "x86_64-linux";

    mkPkgs = pkgs:
      import pkgs {
        inherit system;
        config.allowUnfree = true;
      };
    pkgs = mkPkgs nixpkgs;
    pkgs-unstable = mkPkgs nixpkgs-unstable;

    lib = nixpkgs.lib.extend (final: prev: {
      my = import ./lib {
        inherit pkgs inputs;
        
        lib = final;
      };
    });
  in
  {
    lib = lib.my;

    packages."${system}" = mapModules ./packages (p: pkgs.callPackage p {});

    nixosModules =
      {
        kaas = import ./.;
      }
      // mapModulesRec ./modules import;

    nixosConfigurations = mapHosts ./hosts {};

    devShells."${system}".default = import ./shell.nix { inherit lib pkgs; };
  };
}
