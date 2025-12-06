{ mkShell, inputs, pkgs, stdenv, ... }:

mkShell {
  packages = with pkgs; [
    bash
    sops
    just
    yq
    pwgen
    inputs.clan-core.packages.${stdenv.hostPlatform.system}.clan-cli
    inputs.bun2nix.packages.${stdenv.hostPlatform.system}.default
  ];
}