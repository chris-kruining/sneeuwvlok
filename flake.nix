{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # neovim
    nvf.url = "github:notashelf/nvf";

    # plymouth theme
    nixos-boot.url = "github:Melkor333/nixos-boot";

    firefox.url = "github:nix-community/flake-firefox-nightly";

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

    nixos-wsl = {
      url = "github:nix-community/nixos-wsl";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "";
      };
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    clan-core = {
      url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mydia = {
      url = "github:getmydia/mydia";
    };
  };

  outputs = inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;

      snowfall = {
        namespace = "sneeuwvlok";

        meta = {
          name = "sneeuwvlok";
          title = "Sneeuwvlok";
        };
      };

      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          # Due to *arr stack
          "dotnet-sdk-6.0.428"
          "aspnetcore-runtime-6.0.36"

          # I think this is because of zen
          "qtwebengine-5.15.19"

          # For Nheko, the matrix client
          "olm-3.2.16"
        ];
      };

      overlays = with inputs; [
        fenix.overlays.default
        nix-minecraft.overlay
        flux.overlays.default
      ];

      systems.modules = with inputs; [
        clan-core.nixosModules.default
      ];

      homes.modules = with inputs; [
        stylix.homeModules.stylix
        plasma-manager.homeModules.plasma-manager
      ];
    };
}
