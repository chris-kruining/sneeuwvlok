{ config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
in
{
  options.modules.${user}.shell.toolset.zellij = {
    enable = mkEnableOption "terminal multiplexer";
  };

  config = mkIf config.modules.${user}.shell.toolset.zellij.enable {
    home-manager.users.${user} = {
      home.packages = with pkgs; [ zellij ];

      programs.zellij = {
        enable = true;
        attachExistingSession = true;

        settings = {};
      };
    };
  };
}
