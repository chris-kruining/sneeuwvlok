{ inputs, config, options, lib, pkgs, ... }:
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
    (mkIf config.modules.develop.rust.enable {
      user.packages = attrValues {
        rust-package = pkgs.rust-bin.nightly.latest.default;
        inherit (pkgs) rust-analyser rust-script;
      };

      environment.shellAliases = {
        rs = "rustc";
        ca = "cargo";
      };
    })

    (mkIf config.modules.develop.xdg.enable {
      home = {
        sessionVariables.CARGO_HOME = "$XDG_DATA_HOME/cargo";
        sessionPath = ["$CARGO_HOME/bin"];
      };
    })
  ];
}
