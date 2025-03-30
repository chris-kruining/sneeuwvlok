{ config, lib, ... }: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  cfg = config.modules.shell.zsh;
in
{
  options.modules.shell.zsh = {
    enable = mkEnableOption "enable ZSH";
  };

  config = mkIf cfg.enable {
    programs.zsh.enable = true;
  };
}
