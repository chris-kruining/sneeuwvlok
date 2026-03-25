{lib, ...}: {
  perSystem = {pkgs, ...}: {
    packages.vaultwarden = pkgs.callPackage ./package.nix {};
  };

  flake.overlays."package/vaultwarden" = final: _prev: {
    vaultwarden = final.callPackage ./package.nix {};
  };
}
