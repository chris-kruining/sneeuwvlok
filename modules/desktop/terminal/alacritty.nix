{
  config,
  options,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
in {
  options.modules.desktop.terminal.alacritty = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "OpenGL terminal emulator"; };

  config = mkIf config.modules.desktop.terminal.alacritty.enable {
    modules.shell.toolset.tmux.enable = true;

    hm.programs.alacritty = {
      enable = true;

      settings = mkMerge [
        {
          env = {
            TERM = "xterm-256color";
            WINIT_X11_SCALE_FACTOR = "1.0";
          };

          window.dynamic_title = true;

          scrolling = {
            history = 5000;
            multiplier = 3;
          };

          selection = {
            semantic_escape_chars = '',│`|:"' ()[]{}<>'';
            save_to_clipboard = false;
          };

          live_config_reload = true;

          shell = {
            program = "${getExe pkgs.zsh}";
            args = ["-l" "-c" "tmux new || tmux"];
          };
        }

#         (mkIf (active != null) {
#           import = ["~/.config/alacritty/config/${active}.toml"];
#         })
      ];
    };

#     create.configFile = mkIf (active != null) {
#       alacritty-conf = {
#         target = "alacritty/config/${active}.toml";
#         source = let
#           inherit (config.modules.themes.font) mono sans;
#           tomlFormat = pkgs.formats.toml {};
#         in tomlFormat.generate "alacritty-theme" {
#           font = {
#             builtin_box_drawing = true;
#             size = mono.size;
#
#             normal = {
#               family = "${mono.family}";
#               style = "${sans.weight}";
#             };
#
#             italic = {
#               family = "${mono.family}";
#               style = "${sans.weight} Italic";
#             };
#
#             bold = {
#               family = "${mono.family}";
#               style = "${mono.weight}";
#             };
#
#             bold_italic = {
#               family = "${mono.family}";
#               style = "${mono.weight} Italic";
#             };
#
#             offset = {
#               x = 0;
#               y = 0;
#             };
#             glyph_offset = {
#               x = 0;
#               y = 0;
#             };
#           };
#         };
#       };
#     };
  };
}
