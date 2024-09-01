{ inputs, config, options, lib, pkgs, ... }:
let
  inherit (builtins) elem isList pathExists toString;
  inherit (lib.attrsets) mapAttrs mapAttrsToList;
  inherit (lib.lists) findFirst;
  inherit (lib.modules) mkAliasDefinitions;
  inherit (lib.strings) concatMapStringsSep concatStringsSep;
  inherit (lib.my) mkOpt mkOpt';
in
{
  options = let
    inherit (lib.options) mkOption;
    inherit (lib.types) attrs attrsOf either listOf oneOf path str;
  in
  {
    user = mkOpt attrs {};

    sneeuwvlok = {
      dir = mkOpt path (findFirst pathExists (toString ../.) [
        "${config.user.home}/Github/.files"
      ]);
      hostDir = mkOpt path "${config.sneeuwvlok.dir}/hosts/${config.networking.hostName}";
      configDir = mkOpt path "${config.sneeuwvlok.dir}/config";
      modulesDir = mkOpt path "${config.sneeuwvlok.dir}/modules";
      themesDir = mkOpt path "${config.sneeuwvlok.modulesDir}/themes";
    };
  };

  config = {
    user = let
      user = builtins.getEnv "USER";
      name =
        if builtins.elem user [ "" "root" ] then "chris"
        else user;
    in
    {
      inherit name;
#       description = "Primary user account";
      description = "Chris Kruining";
      extraGroups = [ "wheel" ];
      isNormalUser = true;
      home = "/home/${name}";
      group = "users";
      uid = 1000;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = [
        inputs.plasma-manager.homeManagerModules.plasma-manager
        inputs.nixvim.homeManagerModules.nixvim
      ];
    };

    home = {
      stateVersion = config.system.stateVersion;
      sessionPath = [ "$SNEEUWVLOK_BIN" "$XDG_BIN_HOME" "$PATH" ];
    };

    users.users.${config.user.name} = mkAliasDefinitions options.user;

    nix.settings = let users = [ "root" config.user.name ]; in
    {
      trusted-users = users;
      allowed-users = users;
    };
  };
}
