{ config, lib, pkgs, user, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.shell.toolset.zellij;
in
{
  options.${namespace}.shell.toolset.zellij = {
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
