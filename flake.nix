{
  description = "Nixos config flake";

  nixConfig = {
    warn-dirty = false;
  };

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

    aspire = {
      url = "github:microsoft/aspire";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust toolchain
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Wraps the official release tarball, a bot bumps it a few times a week
    helium = {
      url = "github:amaanq/helium-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

    flux.url = "github:IogaMaster/flux";

    sops-nix.url = "github:Mic92/sops-nix";

    # Declarative partitioning, used by nixos-anywhere when installing a machine
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # OpenTofu providers, as release zips so flake.lock holds their hashes.
    # Bump a provider by changing the version in its url and running `nix flake lock`.
    tofu-provider-radarr = {
      url = "https://github.com/devopsarr/terraform-provider-radarr/releases/download/v2.3.5/terraform-provider-radarr_2.3.5_linux_amd64.zip";
      flake = false;
    };
    tofu-provider-sonarr = {
      url = "https://github.com/devopsarr/terraform-provider-sonarr/releases/download/v3.4.0/terraform-provider-sonarr_3.4.0_linux_amd64.zip";
      flake = false;
    };
    tofu-provider-prowlarr = {
      url = "https://github.com/devopsarr/terraform-provider-prowlarr/releases/download/v3.1.0/terraform-provider-prowlarr_3.1.0_linux_amd64.zip";
      flake = false;
    };
    tofu-provider-lidarr = {
      url = "https://github.com/devopsarr/terraform-provider-lidarr/releases/download/v1.13.0/terraform-provider-lidarr_1.13.0_linux_amd64.zip";
      flake = false;
    };
    tofu-provider-zitadel = {
      url = "https://github.com/zitadel/terraform-provider-zitadel/releases/download/v2.2.0/terraform-provider-zitadel_2.2.0_linux_amd64.zip";
      flake = false;
    };
    tofu-provider-local = {
      url = "https://releases.hashicorp.com/terraform-provider-local/2.6.2/terraform-provider-local_2.6.2_linux_amd64.zip";
      flake = false;
    };

    # Prebuilt jellyfin plugin, bump the version in the url and run `nix flake lock`
    jellyfin-plugin-sso = {
      url = "https://github.com/MaxRink/jellyfin-plugin-sso/releases/download/v6.1.0.0/sso-auth_6.1.0.0.zip";
      flake = false;
    };

    # Home assistant integration for the car. Upstream releases from master, develop carries the betas
    home-assistant-stellantis-vehicles = {
      url = "github:andreadegiovine/homeassistant-stellantis-vehicles/master";
      flake = false;
    };

    clan-core = {
      url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mydia = {
      url = "github:chris-kruining/mydia";
      # url = "github:getmydia/mydia";
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
