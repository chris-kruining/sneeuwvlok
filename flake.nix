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

  outputs = inputs @ {
    flake-parts,
    home-manager,
    nixpkgs,
    ...
  }: let
    inherit (nixpkgs) lib;

    namespace = "sneeuwvlok";

    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    channelConfig = {
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

    packageDefs = {
      studio = {
        path = ./packages/studio/default.nix;
        extra = {
          erosanixLib = inputs.erosanix.lib;
        };
        systems = ["x86_64-linux"];
      };
      vaultwarden = {
        path = ./packages/vaultwarden/default.nix;
        extra = {};
        systems = supportedSystems;
      };
    };

    mkPackageOverlay = name: def: final: prev:
      lib.optionalAttrs (lib.elem final.stdenv.hostPlatform.system def.systems) {
        ${name} = final.callPackage def.path def.extra;
      };

    packageOverlays = {
      "package/studio" = mkPackageOverlay "studio" packageDefs.studio;
      "package/vaultwarden" = mkPackageOverlay "vaultwarden" packageDefs.vaultwarden;
    };

    systemOverlays = with inputs; [
      fenix.overlays.default
      nix-minecraft.overlay
      flux.overlays.default
    ];

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = systemOverlays;
        config = channelConfig;
      };

    collectModules = root: let
      recurse = prefix: dir: let
        entries = builtins.readDir dir;
        selfModule =
          if builtins.pathExists (dir + "/default.nix")
          then {
            "${if prefix == "" then "__root" else prefix}" = dir;
          }
          else {};
      in
        lib.foldl' (acc: name: let
          kind = entries.${name};
          path = dir + "/${name}";
          rel = if prefix == "" then name else "${prefix}/${name}";
          children =
            if kind == "directory"
            then recurse rel path
            else {};
          current =
            if kind == "directory" && builtins.pathExists (path + "/default.nix")
            then {"${rel}" = path;}
            else {};
        in
          acc // children // current) selfModule (builtins.attrNames entries);
    in
      recurse "" root;

    nixosModules = collectModules ./modules/nixos;
    homeModules = collectModules ./modules/home;

    homeEntries = {
      "chris@mandos" = {
        machine = "mandos";
        user = "chris";
        path = ./homes/x86_64-linux + "/chris@mandos";
      };
      "chris@manwe" = {
        machine = "manwe";
        user = "chris";
        path = ./homes/x86_64-linux + "/chris@manwe";
      };
      "chris@orome" = {
        machine = "orome";
        user = "chris";
        path = ./homes/x86_64-linux + "/chris@orome";
      };
      "chris@tulkas" = {
        machine = "tulkas";
        user = "chris";
        path = ./homes/x86_64-linux + "/chris@tulkas";
      };
    };

    sneeuwvlokLib =
      (import ./lib/options {inherit lib;})
      // (import ./lib/strings {inherit lib;});

    machineConfigPaths = builtins.listToAttrs (map (name: lib.nameValuePair name (./machines + "/${name}/configuration.nix")) [
      "aule"
      "mandos"
      "manwe"
      "melkor"
      "orome"
      "tulkas"
      "ulmo"
      "varda"
      "yavanna"
    ]);

    machineHomeModules = lib.mapAttrs' (_: spec: lib.nameValuePair spec.machine [{
      users.users.${spec.user} = {
        isNormalUser = lib.mkDefault true;
      };
      home-manager.users.${spec.user} = import spec.path;
    }]) homeEntries;

    sharedSpecialArgs = {
      inherit namespace;
      erosanixLib = inputs.erosanix.lib;
      repoRoot = ./.;
      inherit sneeuwvlokLib;
      terranixLib = inputs.terranix.lib;
      system = "x86_64-linux";
    };

    homeSharedModules =
      [
        inputs.stylix.homeModules.stylix
        inputs.plasma-manager.homeModules.plasma-manager
        inputs.zen-browser.homeModules.default
      ]
      ++ builtins.attrValues homeModules;

    baseNixosModules =
      [
        { _module.args = sharedSpecialArgs; }
        inputs.grub2-themes.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.himmelblau.nixosModules.himmelblau
        inputs.jovian.nixosModules.default
        inputs.mydia.nixosModules.default
        inputs.nix-minecraft.nixosModules.minecraft-servers
        inputs.nvf.nixosModules.default
        inputs.sops-nix.nixosModules.sops
        {
          nixpkgs = {
            config = channelConfig;
            overlays = systemOverlays;
          };

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = sharedSpecialArgs;
            sharedModules = homeSharedModules;
          };
        }
      ]
      ++ builtins.attrValues nixosModules;

    mkClanMachineModuleList = name:
      baseNixosModules
      ++ (machineHomeModules.${name} or [])
      ++ [
        {
          networking.hostName = lib.mkDefault name;
        }
      ];

    mkMachineModuleList = name:
      mkClanMachineModuleList name
      ++ [
        machineConfigPaths.${name}
      ];

    clanConfig = import ./clan.nix {
      inherit sharedSpecialArgs;
      mkMachineModuleList = mkClanMachineModuleList;
    };

    activeMachineNames = builtins.attrNames clanConfig.machines;

    nixosConfigurations =
      lib.genAttrs activeMachineNames (name:
        lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = sharedSpecialArgs;
          modules = mkMachineModuleList name;
        });

    homeConfigurations =
      lib.mapAttrs (_: spec:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "x86_64-linux";
          extraSpecialArgs =
            sharedSpecialArgs
            // {
              osConfig = nixosConfigurations.${spec.machine}.config;
            };
          modules =
            homeSharedModules
            ++ [
              {
                home.username = spec.user;
                home.homeDirectory = "/home/${spec.user}";
              }
              spec.path
            ];
        })
      homeEntries;
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = supportedSystems;

      imports = [
        inputs.clan-core.flakeModules.default
      ];

      clan = clanConfig;

      perSystem = {
        system,
        ...
      }: let
        pkgs = mkPkgs system;
      in {
        _module.args.pkgs = pkgs;

        packages = lib.filterAttrs (_: value: value != null) {
          studio =
            if lib.elem system packageDefs.studio.systems
            then pkgs.callPackage packageDefs.studio.path packageDefs.studio.extra
            else null;
          vaultwarden =
            if lib.elem system packageDefs.vaultwarden.systems
            then pkgs.callPackage packageDefs.vaultwarden.path packageDefs.vaultwarden.extra
            else null;
        };

        devShells.default = import ./shells/default/default.nix {
          inherit inputs pkgs;
          inherit (pkgs) mkShell stdenv;
        };
      };

      flake = {
        inherit homeConfigurations;
        nixosConfigurations = lib.mkForce nixosConfigurations;

        lib = sneeuwvlokLib;

        overlays =
          packageOverlays
          // {
            default = lib.composeManyExtensions (builtins.attrValues packageOverlays);
          };
      };
    };
}
