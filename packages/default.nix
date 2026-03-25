{
  config,
  lib,
  mkPkgs,
  ...
}: {
  imports = [
    ./studio
    ./vaultwarden
  ];

  perSystem = {system, ...}: let
    pkgs = mkPkgs system;
  in {
    _module.args.pkgs = pkgs;

    clan.pkgs = pkgs;
  };

  flake.overlays.default = lib.composeManyExtensions [
    config.flake.overlays."package/studio"
    config.flake.overlays."package/vaultwarden"
  ];
}
