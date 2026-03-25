{inputs, lib, ...}: {
  perSystem = {pkgs, system, ...}: {
    packages = lib.optionalAttrs (system == "x86_64-linux") {
      studio = pkgs.callPackage ./package.nix {
        erosanixLib = inputs.erosanix.lib;
      };
    };
  };

  flake.overlays."package/studio" = final: _prev:
    lib.optionalAttrs (final.stdenv.hostPlatform.system == "x86_64-linux") {
      studio = final.callPackage ./package.nix {
        erosanixLib = inputs.erosanix.lib;
      };
    };
}
