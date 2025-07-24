{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.shell.zsh;
in
{
  options.${namespace}.shell.zsh = {
    enable = mkEnableOption "enable zsh shell";
  };

  config = mkIf cfg.enable {
    # Enable completion for sys-packages:
    environment.pathsToLink = ["/share/zsh"];
  };
}
