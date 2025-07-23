{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

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

    himmelblau = {
      url = "github:himmelblau-idm/himmelblau/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    erosanix.url = "github:emmanuelrosa/erosanix";

    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, nix-minecraft, flux, ... }:
  let
    inherit (lib.my) readNixosModules mapHosts;

    system = "x86_64-linux";

    mkPkgs = pkgs: extraOverlays:
      import pkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = extraOverlays ++ (lib.attrValues self.overlays);
      };
    pkgs = mkPkgs nixpkgs [self.overlays.default nix-minecraft.overlay flux.overlays.default];

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
        my = self.packages.${system};
      };
    };

    packages."${system}" = lib.my.mapModules ./packages (p: pkgs.callPackage p { inherit inputs; });

    nixosModules = readNixosModules ./modules import;
    nixosConfigurations = mapHosts ./hosts {};
  };
}
