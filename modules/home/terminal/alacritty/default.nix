{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.terminal.alacritty;
in {
  options.sneeuwvlok.terminal.alacritty = {
    enable = mkEnableOption "enable alacritty";
  };

  config = mkIf cfg.enable {
    programs.alacritty = {
      enable = true;

      settings = {
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

        # terminal.shell = {
        #   program = "${getExe pkgs.zsh}";
        #   args = ["-l" "-c" "tmux new || tmux"];
        # };
      };
    };
  };
}
