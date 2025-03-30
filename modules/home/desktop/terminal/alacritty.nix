{
  config,
  options,
  lib,
  pkgs,
  user,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
in {
  options.modules.${user}.desktop.terminal.alacritty = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "OpenGL terminal emulator"; };

  config = mkIf config.modules.${user}.desktop.terminal.alacritty.enable {
    modules.${user}.shell.toolset.tmux.enable = true;

    home-manager.users.${user}.programs.alacritty = {
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

          general.live_config_reload = true;

          terminal.shell = {
            program = "${getExe pkgs.zsh}";
            args = ["-l" "-c" "tmux new || tmux"];
          };
        }
      ];
    };
  };
}
