{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.shell.toolset.zellij;
in
{
  options.sneeuwvlok.shell.toolset.zellij = {
    enable = mkEnableOption "terminal multiplexer";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ zellij ];

    programs.zellij = {
      enable = true;
      attachExistingSession = true;

      settings = {};
    };
  };
}
