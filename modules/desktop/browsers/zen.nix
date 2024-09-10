{ inputs, options, config, lib, pkgs, ... }:
let
  inherit (builtins) toJSON;
  inherit (lib.attrsets) attrValues mapAttrsToList;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.strings) concatStrings;

  cfg = config.modules.desktop.browsers.zen;
in {
  options.modules.desktop.browsers.zen = let
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
    (mkIf (config.modules.desktop.type == "wayland") {
      environment.variables.MOZ_ENABLE_WAYLAND = "1";
    })

    (mkIf cfg.enable {
      user.packages = let
        inherit (pkgs) makeDesktopItem;
        inherit (inputs.zen.packages.${pkgs.system}.specific) zen;
      in [
        zen
#         (makeDesktopItem {
#           name = "zen";
#           desktopName = "Zen";
#           genericName = "Launch a Zen instance";
#           icon = "zen";
#           exec = "${lib.getExe zen-bin}";
#           categories = ["Network" "WebBrowser"];
#         })
      ];

      # Use a stable profile name so we can target it in themes
#       home.file = let
#         cfgPath = ".mozilla/firefox";
#       in {
#         firefox-profiles = {
#           target = "${cfgPath}/profiles.ini";
#           text = ''
#             [Profile0]
#             Name=default
#             IsRelative=1
#             Path=${cfg.profileName}.default
#             Default=1
#
#             [General]
#             StartWithLastProfile=1
#             Version=2
#           '';
#         };
#
#         user-js = mkIf (cfg.settings != {} || cfg.extraConfig != "") {
#           target = "${cfgPath}/${cfg.profileName}.default/user.js";
#           text = ''
#             ${concatStrings (mapAttrsToList (name: value: ''
#                 user_pref("${name}", ${toJSON value});
#               '')
#               cfg.settings)}
#             ${cfg.extraConfig}
#           '';
#         };
#
#         user-chrome = mkIf (cfg.userChrome != "") {
#           target = "${cfgPath}/${cfg.profileName}.default/chrome/userChrome.css";
#           text = cfg.userChrome;
#         };
#
#         user-content = mkIf (cfg.userContent != "") {
#           target = "${cfgPath}/${cfg.profileName}.default/chrome/userContent.css";
#           text = cfg.userContent;
#         };
#       };
    })
  ];
}
