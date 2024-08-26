{ config, options, lib, pkgs, ... }:
let
  inherit (builtins) toString readFile;
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkDefault mkIf mkMerge;
  inherit (lib.strings) concatMapStringsSep;

  cfg = config.modules.themes;
in
{
  config = mkIf (cfg.active == "everforest")
  {
#     stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/everforest.yaml";
#     stylix.image = ./assets/wallpaper.jpg;

#     modules.themes = {
#       wallpaper = mkDefault ./assets/wallpaper.jpg;
#
#       gtk = {
#         name = "Everforest-Dark-BL";
#         package = pkgs.my.everforest-gtk;
#       };
#
#       iconTheme = {
#         name = "everforest-dark";
#         package = pkgs.fluent-icon-theme.override {
#           colorVariants = [];
#         };
#       };
#
#       pointer = {
#         name = "Bibata-Modern-Classic";
#         package = pkgs.bibata-cursors;
#         size = 24;
#       };
#
#       fontConfig = {
#         packages = attrValues {
#           inherit (pkgs) noto-fonts-emoji sarasa-gothic;
#           google-fonts = pkgs.google-fonts.override {fonts = ["Cardo"];};
#           nerdfonts =
#             pkgs.nerdfonts.override {fonts = ["CascadiaCode" "VictorMono"];};
#         };
#         mono = ["VictorMono Nerd Font" "Sarasa Mono SC"];
#         sans = ["Caskaydia Cove Nerd Font" "Sarasa Gothic SC"];
#         emoji = ["Noto Color Emoji"];
#       };
#
#       font = {
#         mono.family = "VictorMono Nerd Font";
#         sans.family = "CaskaydiaCove Nerd Font";
#       };
#
#       colors = {
#         main = {
#           normal = {
#             black = "#15161e";
#             red = "#f7768e";
#             green = "#9ece6a";
#             yellow = "#e0af68";
#             blue = "#7aa2f7";
#             magenta = "#bb9af7";
#             cyan = "#7dcfff";
#             white = "#a9b1d6";
#           };
#           bright = {
#             black = "#414868";
#             red = "#f7768e";
#             green = "#9ece6a";
#             yellow = "#e0af68";
#             blue = "#7aa2f7";
#             magenta = "#bb9af7";
#             cyan = "#7dcfff";
#             white = "#c0caf5";
#           };
#           types = {
#             fg = "#c0caf5";
#             bg = "#1a1b26";
#             panelbg = "#ff9e64";
#             border = "#1abc9c";
#             highlight = "#3d59a1";
#           };
#         };
#
#         rofi = {
#           bg = {
#             main = "hsla(235, 18%, 12%, 1)";
#             alt = "hsla(235, 18%, 12%, 0)";
#             bar = "hsla(229, 24%, 18%, 1)";
#           };
#           fg = "hsla(228, 72%, 85%, 1)";
#           ribbon = {
#             outer = "hsla(188, 68%, 27%, 1)";
#             inner = "hsla(202, 76%, 24%, 1)";
#           };
#           selected = "hsla(220, 88%, 72%, 1)";
#           urgent = "hsl(349, 89%, 72%, 1)";
#           transparent = "hsla(0, 0%, 0%, 0)";
#         };
#       };
#
#       editor = {
#         neovim = {
#           dark = "everforest";
#           light = "everforest";
#         };
#       };
#     };
  };
}
