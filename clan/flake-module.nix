{
  lib,
  inputs,
  ...
}: {
  imports = [
    ./machines.nix
    ./tags.nix
    ./instances.nix
  ];

  clan = {
    meta = {
      name = "arda";
      domain = "arda";
      description = "My personal machines at home";
    };

    directory = ../.;

    specialArgs = {
      ardaLib = {
        endpoints = import ../lib/endpoints.nix {
          inherit lib;
          clanLib = inputs.clan-core.lib;
        };

        clanServices = import ../lib/clan-services.nix {
          inherit lib;
        };

        types =
          ./types
          |> (inputs.import-tree.withLib lib).leafs
          |> lib.map (mod: {
            name = mod |> lib.baseNameOf |> lib.splitString "." |> lib.head;
            value = lib.types.submoduleWith {modules = [mod];};
          })
          |> lib.listToAttrs;
      };
    };

    exportInterfaces =
      ./interfaces
      |> (inputs.import-tree.withLib lib).leafs
      |> lib.map (mod: {
        name = mod |> lib.baseNameOf |> lib.splitString "." |> lib.head;
        value = import mod;
      })
      |> lib.listToAttrs;
  };
}
