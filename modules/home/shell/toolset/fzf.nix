{ config, lib, pkgs, user, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  defShell = config.modules.${user}.shell.default;
in
{
  options.modules.${user}.shell.toolset.fzf = {
    enable = mkEnableOption "TUI Fuzzy Finder.";
  };

  config = mkIf config.modules.${user}.shell.toolset.fzf.enable {
    home-manager.users.${user} = {
      home.packages = with pkgs; [ fzf ];

      programs.fzf = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = defShell == "zsh";
        enableFishIntegration = defShell == "fish";

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
  };
}
