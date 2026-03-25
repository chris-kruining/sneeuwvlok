{
  description = "Nixos config flake";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "clan-core/nixpkgs";
    };

    clan-core = {
      url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
      inputs.flake-parts.follows = "flake-parts";
    };

    nixpkgs.follows = "clan-core/nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Legacy ISO flow removed in favor of Clan install workflows.
    # nixos-generators = {
    #   url = "github:nix-community/nixos-generators";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # neovim
    nvf.url = "github:notashelf/nvf";

    # Unused input retained as a comment for easy recovery.
    # nixos-boot.url = "github:Melkor333/nixos-boot";

    # Unused input retained as a comment for easy recovery.
    # firefox.url = "github:nix-community/flake-firefox-nightly";

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

    # Unused input retained as a comment for easy recovery.
    # nixos-wsl = {
    #   url = "github:nix-community/nixos-wsl";
    #   inputs = {
    #     nixpkgs.follows = "nixpkgs";
    #     flake-compat.follows = "";
    #   };
    # };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mydia = {
      url = "github:chris-kruining/mydia";
      # url = "github:getmydia/mydia";
    };
  };

  outputs = inputs@{flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        inputs.clan-core.flakeModules.default
        inputs.home-manager.flakeModules.home-manager
        ./lib/default.nix
        ./machines/default.nix
        ./packages/default.nix
        ./shells/default/default.nix
        ./users/default.nix
      ];
    };
}
