{ config, lib, ... }:
let
  inherit (lib.modules) mkIf;

  cfg = config.modules.shell.zsh;
in
{
  options.modules.shell.zsh = let
    inherit (lib.options) mkEnableOption;
  in
  {
    enable = mkEnableOption "enable ZSH";
  };

  config = mkIf cfg.enable {
    programs.zsh.enable = true;
  };
}
