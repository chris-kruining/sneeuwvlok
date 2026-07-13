{
  clanLib,
  lib,
}: {
  description = "Assign generated endpoint ports for one machine";
  interface = import ../interfaces/default.nix;

  perInstance = {
    exports,
    machine,
    mkExports,
    settings,
    ...
  }: let
    endpointsLib = import ../../../lib/endpoints.nix {inherit lib;};

    readClaims = value: let
      result = builtins.tryEval (value.ports.claims or {});
    in
      if result.success
      then result.value
      else {};

    claimSets =
      exports
      |> clanLib.selectExports (scope: scope.machineName == machine.name)
      |> lib.mapAttrsToList (_scope: readClaims);

    claimNames =
      claimSets
      |> lib.concatMap lib.attrNames;
  in {
    exports = mkExports {
      ports.assigned = endpointsLib.assignPorts {
        machineName = machine.name;
        range = settings.range;
        inherit claimNames;
      };
    };
  };
}
