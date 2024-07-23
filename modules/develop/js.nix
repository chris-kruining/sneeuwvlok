{ inputs, config, options, lib, pkgs, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge;
in
{
  options.modules.develop.js = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "JS developmnt";
  };

  config = mkMerge [
    (mkIf config.modules.develop.js.enable {
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
