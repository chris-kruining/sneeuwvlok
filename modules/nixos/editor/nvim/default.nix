{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.editor.nvim;
in
{
  options.sneeuwvlok.editor.nvim = {
    enable = mkEnableOption "enable nvim via nvf on system level";
  };

  config = mkIf cfg.enable {
  };
}
