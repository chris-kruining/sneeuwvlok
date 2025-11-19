{ mkShell, inputs, pkgs, ... }:

mkShell {
  packages = with pkgs; [
    bash
    sops
    just
    yq
    pwgen
    inputs.clan-core.packages.x86_64-linux.clan-cli
  ];
}