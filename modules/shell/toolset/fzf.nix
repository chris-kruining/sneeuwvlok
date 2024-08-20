{ config, options, lib, pkgs, ... }:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.modules) mkIf;
in
{
  options.modules.shell.toolset.fzf = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "TUI Fuzzy Finder."; };

  config = mkIf config.modules.shell.toolset.fzf.enable {
    hm.programs.fzf = let
      defShell = config.modules.shell.default;
    in {
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
}
