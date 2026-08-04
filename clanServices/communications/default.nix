{
  ardaLib,
  lib,
  ...
}: let
  inherit (lib) mkMerge mkOption types;

  drivers = ardaLib.clanServices.discoverDrivers {
    dir = ./drivers;
    inherit lib;
  };

  driverInterfaces = drivers |> lib.mapAttrs (_: driver: driver.interface);
in {
  _class = "clan.service";
  manifest = {
    name = "communications";
    description = "Generic communications service";
    categories = ["Service" "Communication"];
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["gateway" "identity" "observability" "persistence"];
      out = ["gateway" "identity" "observability" "persistence"];
    };
  };

  roles.default = {
    description = "Matrix communications service";
    interface = {
      options = {
        driver = mkOption {
          type = types.enum (driverInterfaces |> lib.attrNames);
          default = "matrix";
        };

        settings = mkOption {
          type = types.oneOf (driverInterfaces |> lib.attrValues);
        };

        identity = mkOption {
          type = types.submoduleWith {
            modules = [../../clan/interfaces/identity.nix];
          };
          default = {};
        };
      };
    };

    perInstance = args @ {
      settings,
      mkExports,
      ...
    }: let
      fragments = ardaLib.clanServices.driverRoleFragments {
        serviceName = "communications";
        inherit drivers;
        driver = settings.driver;
        roleName = "default";
        roleArgs = args;
      };
    in {
      exports = mkExports (mkMerge fragments.exports);

      nixosModule = moduleArgs: {
        config = mkMerge ([] ++ (fragments.nixosModules moduleArgs));
      };
    };
  };
}
