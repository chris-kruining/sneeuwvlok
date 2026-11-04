{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.shell.toolset.fzf;
in
{
  options.${namespace}.shell.toolset.fzf = {
    enable = mkEnableOption "TUI Fuzzy Finder.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ fzf ];

    programs.fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = true;

      tmux.enableShellIntegration = true;
      tmux.shellIntegrationOptions = ["-d 40%"];

      defaultCommand = "fd --type f";
      defaultOptions = ["--height 40%" "--border"];

      changeDirWidget = {
        command = "fd --type d";
        options = ["--preview 'tree -C {} | head -200'"];
      };

      fileWidget = {
        command = "fd --type f";
        options = ["--preview 'head {}'"];
      };

      historyWidget = {
        options = ["--sort" "--exact"];
      };
    };
  };
}
