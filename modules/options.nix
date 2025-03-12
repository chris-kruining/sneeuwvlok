{ inputs, config, options, lib, pkgs, ... }:
let
  inherit (builtins) pathExists toString;
  inherit (lib.lists) findFirst;
  inherit (lib.modules) mkAliasDefinitions;
in
{
  options = let
    inherit (lib.types) attrs path;
    inherit (lib.my) mkOpt;
  in
  {
    user = mkOpt attrs {};

    sneeuwvlok = {
      dir = mkOpt path (findFirst pathExists (toString ../.) [
        "${config.user.home}/Github/sneeuwvlok"
      ]);
      hostDir = mkOpt path "${config.sneeuwvlok.dir}/hosts/${config.networking.hostName}";
      configDir = mkOpt path "${config.sneeuwvlok.dir}/config";
      modulesDir = mkOpt path "${config.sneeuwvlok.dir}/modules";
      themesDir = mkOpt path "${config.sneeuwvlok.modulesDir}/themes";
    };
  };

  config = {
    user = {
      name = "chris";
      description = "Chris Kruining";
      extraGroups = [ "wheel" ];
      isNormalUser = true;
      home = "/home/chris";
      group = "users";
      uid = 1000;
    };

    users.users.${config.user.name} = mkAliasDefinitions options.user;

    nix.settings = let
      inherit (lib) attrNames filterAttrs;

      users = (attrNames (filterAttrs ({ is_trusted ? false }: is_trusted) config.users)) ++ [ "root" ];
    in
      {
        trusted-users = users;
        allowed-users = users;
      };
  };
}
