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

    nvf.url = "github:notashelf/nvf";

    nixos-boot.url = "github:Melkor333/nixos-boot";

    firefox.url = "github:nix-community/flake-firefox-nightly";

    stylix.url = "github:danth/stylix";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser.url = "github:MarceColl/zen-browser-flake";

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    flux.url = "github:IogaMaster/flux";

    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs @ { self, nixpkgs, nixpkgs-unstable, nix-minecraft, flux, ... }:
  let
    inherit (lib.my) mapModules mapModulesRec mapHosts;

    system = "x86_64-linux";

    mkPkgs = pkgs: extraOverlays:
      import pkgs {
        inherit system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "dotnet-sdk-6.0.428"
          "aspnetcore-runtime-6.0.36"
        ];
        overlays = extraOverlays ++ (lib.attrValues self.overlays);
      };
    pkgs = mkPkgs nixpkgs [self.overlays.default nix-minecraft.overlay flux.overlays.default];
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
  };
}
