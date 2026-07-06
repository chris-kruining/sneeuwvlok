{
  config,
  inputs,
  lib,
  mkPkgs,
  sharedContext,
  ...
}: let
  inherit (lib) mkOption types;

  mkHomeUserModule = spec:
    (import spec.path {}).home-manager.users.${spec.user};
in {
  options.localUsers = {
    homeEntries = mkOption {
      type = types.attrsOf types.raw;
      default = {};
    };

    homeSharedModules = mkOption {
      type = types.listOf types.raw;
      default = [];
    };
  };

  config = {
    localUsers.homeEntries = {
      "chris@mandos" = {
        machine = "mandos";
        user = "chris";
        path = ../users/chris/mandos.nix;
      };
      "chris@manwe" = {
        machine = "manwe";
        user = "chris";
        path = ../users/chris/manwe.nix;
      };
      "chris@orome" = {
        machine = "orome";
        user = "chris";
        path = ../users/chris/orome.nix;
      };
      "chris@tulkas" = {
        machine = "tulkas";
        user = "chris";
        path = ../users/chris/tulkas.nix;
      };
    };

    localUsers.homeSharedModules =
      [
        inputs.stylix.homeModules.stylix
        inputs.plasma-manager.homeModules.plasma-manager
        inputs.zen-browser.homeModules.default
      ]
      ++ [ ../modules/home ];

    flake.homeConfigurations = lib.mapAttrs (_: spec:
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs "x86_64-linux";
        extraSpecialArgs =
          sharedContext
          // {
            osConfig = config.flake.nixosConfigurations.${spec.machine}.config;
          };
        modules =
          config.localUsers.homeSharedModules
          ++ [
            {
              home.username = spec.user;
              home.homeDirectory = "/home/${spec.user}";
            }
            (mkHomeUserModule spec)
          ];
      })
    config.localUsers.homeEntries;
  };
}
