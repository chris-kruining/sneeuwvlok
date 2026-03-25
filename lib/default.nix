{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  namespace = "sneeuwvlok";

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

  systemOverlays = with inputs; [
    fenix.overlays.default
    nix-minecraft.overlay
    flux.overlays.default
  ];

  mkPkgs = system:
    import inputs.nixpkgs {
      inherit system;
      overlays = systemOverlays;
      config = channelConfig;
    };

  sharedContext = {
    inherit inputs namespace;
    erosanixLib = inputs.erosanix.lib;
    repoRoot = ../.;
    sneeuwvlokLib = config.localLib;
    terranixLib = inputs.terranix.lib;
  };

  baseNixosModules =
    [
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
          extraSpecialArgs = sharedContext;
          sharedModules = config.localUsers.homeSharedModules;
        };
      }
    ]
    ++ [ ../modules/nixos ];
in {
  imports = [
    ./options
    ./strings
  ];

  options.localLib = mkOption {
    type = types.lazyAttrsOf types.raw;
    default = {};
  };

  config = {
    _module.args = {
      inherit
        baseNixosModules
        channelConfig
        mkPkgs
        sharedContext
        systemOverlays
        ;
      sneeuwvlokLib = config.localLib;
    };

    flake.lib = config.localLib;
  };
}
