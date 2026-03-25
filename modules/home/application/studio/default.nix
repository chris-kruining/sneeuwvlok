{ config, lib, pkgs, namespace, repoRoot, erosanixLib, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.studio;
  studioPackage = pkgs.callPackage (repoRoot + "/packages/studio/package.nix") {
    inherit erosanixLib;
  };
in
{
  options.sneeuwvlok.application.studio = {
    enable = mkEnableOption "enable Bricklink Studio";
  };

  config = mkIf cfg.enable {
    home.packages = [ studioPackage ];
  };
}
