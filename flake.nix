{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
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

    zen-browser.url = "github:MarceColl/zen-browser-flake";

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
  };

  outputs = inputs: inputs.snowfall-lib.mkFlake {
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
        "dotnet-sdk-6.0.428"
        "aspnetcore-runtime-6.0.36"
      ];
    };

    overlays = with inputs; [
      fenix.overlays.default
      nix-minecraft.overlay
      flux.overlays.default
    ];
    
    homes.modules = with inputs; [
      stylix.homeModules.stylix
      plasma-manager.homeManagerModules.plasma-manager
    ];
  };
}
