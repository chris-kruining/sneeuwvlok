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

  outputs = inputs: inputs.snowfall-lib.mkFlake {
    inherit inputs;
    src = ./.;

    channels-config = {
      allowUnfree = true;
    };

    snowfall = {
      namespace = "sneeuwvlok";

      meta = {
        name = "sneeuwvlok";
        title = "Sneeuwvlok";
      };
    };

    overlays = with inputs; [
      fenix.overlays.default
      nix-minecraft.overlay
      flux.overlays.default
    ];
  };
}
