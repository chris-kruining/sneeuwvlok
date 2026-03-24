{ config, lib, pkgs, namespace, repoRoot, erosanixLib, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.studio;
  studioPackage = pkgs.callPackage (repoRoot + "/packages/studio/default.nix") {
    inherit erosanixLib;
  };
in
{
  options.${namespace}.application.studio = {
    enable = mkEnableOption "enable Bricklink Studio";
  };

  config = mkIf cfg.enable {
    home.packages = [ studioPackage ];
  };
}
