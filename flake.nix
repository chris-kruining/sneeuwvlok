{
  description = "Nixos config flake";

  nixConfig = {
    warn-dirty = false;
    extra-experimental-features = ["nix-command" "flakes" "pipe-operators"];
  };

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "clan-core/nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";

    clan-core = {
      url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
      inputs.flake-parts.follows = "flake-parts";
    };

    nixpkgs.follows = "clan-core/nixpkgs";
    systems.url = "github:nix-systems/default";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # neovim
    nvf.url = "github:notashelf/nvf";

    stylix.url = "github:nix-community/stylix";

    # Rust toolchain
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

    flux.url = "github:IogaMaster/flux";

    sops-nix.url = "github:Mic92/sops-nix";

    # Azure AD for linux
    himmelblau = {
      url = "github:himmelblau-idm/himmelblau";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # windows app utilities
    erosanix.url = "github:emmanuelrosa/erosanix";

    # Steam deck stuff
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mydia = {
      url = "github:chris-kruining/mydia";
      # url = "github:getmydia/mydia";
    };
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;
      clan = import ./clan.nix;

      imports = with inputs; [
        flake-parts.flakeModules.modules
        clan-core.flakeModules.default
      ];

      perSystem = {system, ...}: {
        _module.args = {
          pkgs = import nixpkgs {
            inherit system;

            overlays = with inputs; [
              fenix.overlays.default
              nix-minecraft.overlay
              flux.overlays.default
            ];

            config = {
              allowUnfree = true;
              permittedInsecurePackages = [
                # I think this is because of zen
                "qtwebengine-5.15.19"
              ];
            };
          };
        };
      };
    };
}
