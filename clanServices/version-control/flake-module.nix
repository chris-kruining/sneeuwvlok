{
  inputs,
  lib,
  ...
}: let
  module = import ./default.nix {
    inherit lib;
    ardaLib.endpoints = import ../../lib/endpoints.nix {
      inherit lib;
      clanLib = inputs.clan-core.lib;
    };
  };
in {
  clan.modules."version-control" = module;
}
