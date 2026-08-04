{
  config,
  lib,
  ...
}: let
  module = import ./default.nix {
    inherit lib;
    ardaLib = config.clan.specialArgs.ardaLib;
  };
in {
  clan.modules.communications = module;
}
