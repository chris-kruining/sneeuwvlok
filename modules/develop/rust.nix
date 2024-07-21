{ config, options, lib, pkgs, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.meta) getExe;
in
{
  options.modules.develop.rust = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Rust developmnt";
  };

  config = mkMerge [
    (mkIf config.modules.develop.rust.enable (
      nixpkgs.overlays = [ inputs.rust.overlays.default ];

      user.packages = attrValues {
        rust-package = pkgs.rust-bin.nightly.latest.default;
        inherit (pkgs) rust-analyser rust-script;
      };

      environment.shellAlliases = {
        rs = "rustc";
        ca = "cargo";
      };
    ))

    (mkIf config.modules.develop.cdg.enable {
      env = {
        CARGO_HOME = "$XDG_DATA_HOME/cargo";
        PATH = [ "$CARGO_HOME/bin" ];
      };
    })
  ];
}
