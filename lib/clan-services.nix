{lib, ...}: let
  availableNames = attrs: let
    names = lib.attrNames attrs;
  in
    if names == []
    then "<none>"
    else lib.concatStringsSep ", " names;

  driverFiles = dir:
    dir
    |> builtins.readDir
    |> lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name);

  loadDriver = pureArgs: dir: name: _: {
    name = lib.removeSuffix ".nix" name;
    value = import (dir + "/${name}") pureArgs;
  };
in {
  discoverDrivers = {
    dir,
    ...
  } @ args:
    driverFiles dir
    |> lib.mapAttrs' (loadDriver (builtins.removeAttrs args ["dir"]) dir);

  driverRoleFragments = {
    serviceName,
    drivers,
    driver,
    roleName ? "default",
    roleArgs,
  }: let
    selectedDriver =
      if builtins.hasAttr driver drivers
      then drivers.${driver}
      else
        throw ''
          Clan service "${serviceName}" selected missing driver "${driver}".
          Available drivers: ${availableNames drivers}
          Expected driver file shape: clanServices/${serviceName}/drivers/${driver}.nix exposes { interface = ...; roles.<roleName> = { exports = ...; nixosModules = ...; }; }
        '';

    roles = selectedDriver.roles or {};

    selectedRole =
      if builtins.hasAttr roleName roles
      then roles.${roleName}
      else
        throw ''
          Clan service "${serviceName}" driver "${driver}" selected missing role "${roleName}".
          Available roles: ${availableNames roles}
          Expected role attr shape: clanServices/${serviceName}/drivers/${driver}.nix exposes roles.${roleName}.{exports,nixosModules}.
        '';
  in
    if !(selectedRole ? exports) || !(selectedRole ? nixosModules)
    then
      throw ''
        Clan service "${serviceName}" driver "${driver}" role "${roleName}" has an invalid shape.
        Expected role attr shape: clanServices/${serviceName}/drivers/${driver}.nix exposes roles.${roleName}.{exports,nixosModules}.
      ''
    else {
      exports = [ (selectedRole.exports roleArgs) ];
      nixosModules = moduleArgs: selectedRole.nixosModules roleArgs moduleArgs;
    };
}
