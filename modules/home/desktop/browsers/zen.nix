{ inputs, options, config, lib, pkgs, user, ... }:
let
  inherit (builtins) toJSON;
  inherit (lib.attrsets) attrValues mapAttrsToList;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.strings) concatStrings;

  cfg = config.modules.${user}.desktop.browsers.zen;
in {
  options.modules.${user}.desktop.browsers.zen = let
    inherit (lib.options) mkEnableOption;
    inherit (lib.types) attrsOf oneOf bool int lines str;
    inherit (lib.my) mkOpt mkOpt';
  in {
    enable = mkEnableOption "Gecko-based libre browser";
    privacy.enable = mkEnableOption "Privacy Focused Firefox fork";

    profileName = mkOpt str config.user.name;
    settings = mkOpt' (attrsOf (oneOf [bool int str])) {} ''
      Firefox preferences set in <filename>user.js</filename>
    '';
    extraConfig = mkOpt' lines "" ''
      Extra lines to add to <filename>user.js</filename>
    '';
    userChrome = mkOpt' lines "" "CSS Styles for Firefox's interface";
    userContent = mkOpt' lines "" "Global CSS Styles for websites";
  };

  config = mkMerge [
    (mkIf (config.modules.${user}.desktop.type == "wayland") {
      environment.variables.MOZ_ENABLE_WAYLAND = "1";
    })

    (mkIf cfg.enable {
      home-manager.users.${user}.home.packages = let
        inherit (pkgs) makeDesktopItem;
        inherit (inputs.zen.packages.${pkgs.system}.specific) zen;
      in [
        zen
      ];
    })
  ];
}
