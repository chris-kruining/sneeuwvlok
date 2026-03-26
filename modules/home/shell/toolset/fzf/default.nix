{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.shell.toolset.fzf;
in {
  options.sneeuwvlok.shell.toolset.fzf = {
    enable = mkEnableOption "TUI Fuzzy Finder.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [fzf];

    programs.fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = true;

      tmux.enableShellIntegration = true;
      tmux.shellIntegrationOptions = ["-d 40%"];

      defaultCommand = "fd --type f";
      defaultOptions = ["--height 40%" "--border"];

      changeDirWidgetCommand = "fd --type d";
      changeDirWidgetOptions = ["--preview 'tree -C {} | head -200'"];

      fileWidgetCommand = "fd --type f";
      fileWidgetOptions = ["--preview 'head {}'"];
      historyWidgetOptions = ["--sort" "--exact"];
    };
  };
}
