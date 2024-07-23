{ inputs, config, options, lib, pkgs, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge;
in
{
  options.modules.develop.dotnet = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Rust developmnt";
  };

  config = mkMerge [
    (mkIf config.modules.develop.dotnet.enable {
      user.packages = attrValues {
      };

    })

    (mkIf config.modules.develop.xdg.enable {
      home = {
#         sessionVariables.CARGO_HOME = "$XDG_DATA_HOME/cargo";
#         sessionPath = ["$CARGO_HOME/bin"];
      };
    })
  ];
}
