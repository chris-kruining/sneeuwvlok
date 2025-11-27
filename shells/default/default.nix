{
  mkShell,
  inputs,
  pkgs,
  stdenv,
  ...
}:
mkShell {
  packages = with pkgs; [
    bash
    sops
    just
    yq
    pwgen
    alejandra
    nil
    nixd
    inputs.clan-core.packages.${stdenv.hostPlatform.system}.clan-cli
  ];
}
