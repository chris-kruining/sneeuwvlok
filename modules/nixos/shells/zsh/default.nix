{
  inputs,
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.shell.zsh;
in {
  options.sneeuwvlok.shell.zsh = {
    enable = mkEnableOption "enable zsh shell";
  };

  config = mkIf cfg.enable {
    # Enable completion for sys-packages:
    environment.pathsToLink = ["/share/zsh"];
  };
}
