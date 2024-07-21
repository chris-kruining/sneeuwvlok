{ config, options, lib, pkgs, ... }:
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

    kaas = {
      dir = mkOpt path (findFirst pathExists (toString ../.) [
        "${config.user.home}/Workspace/public/kaas"
        "/etc/kaas"
      ]);
      hostDir = mkOpt path "${config.kaas.dir}/hosts/${config.networking.hostName}";
      binDir = mkOpt path "${config.kaas.dir}/bin";
      configDir = mkOpt path "${config.kaas.dir}/config";
      modulesDir = mkOpt path "${config.kaas.dir}/modules";
      themesDir = mkOpt path "${config.kaas.modulesDir}/themes";
    };

    home = {
      # HIER BEN IK GEBLEVEN!!!
    };
  };
}
