{ inputs, config, options, lib, pkgs, user, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge;
in
{
  options.modules.${user}.develop.js = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "JS developmnt";
  };

  config = mkMerge [
    (mkIf config.modules.${user}.develop.js.enable {
      user.packages = with pkgs; [
        bun
        nodejs
        nodePackages_latest.typescript-language-server
      ];

    })

    (mkIf config.modules.${user}.develop.xdg.enable {
      # home = {
      # };
    })
  ];
}
