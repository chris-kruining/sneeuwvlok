{
  inputs,
  ...
}: {
  perSystem = {pkgs, system, ...}: {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        bash
        sops
        just
        yq
        pwgen
        alejandra
        nil
        nixd
        openssl
        inputs.clan-core.packages.${system}.clan-cli
        nix-output-monitor
      ];
    };
  };
}
