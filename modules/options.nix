{ inputs, config, options, lib, pkgs, ... }:
let
  inherit (builtins) pathExists toString;
  inherit (lib.lists) findFirst;
  inherit (lib.modules) mkAliasDefinitions;
in
{
  options = let
    inherit (lib.types) attrs path str;
    inherit (lib.my) mkOpt;
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
    environment.systemPackages = [
      pkgs.sops
    ];

    user = {
      name = "chris";
      description = "Chris Kruining";
      extraGroups = [ "wheel" ];
      isNormalUser = true;
      home = "/home/chris";
      group = "users";
      uid = 1000;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = [
        inputs.plasma-manager.homeManagerModules.plasma-manager
      ];
    };

    home = {
      stateVersion = config.system.stateVersion;
      sessionPath = [ "$SNEEUWVLOK_BIN" "$XDG_BIN_HOME" "$PATH" ];
    };

    users.users = {
      ${config.user.name} = mkAliasDefinitions options.user;
    };

    nix.settings = let users = [ "root" config.user.name ]; in
    {
      trusted-users = users;
      allowed-users = users;
    };
  };
}
