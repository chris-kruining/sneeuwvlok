{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.shell.toolset.yazi;
in {
  options.sneeuwvlok.shell.toolset.yazi = {
    enable = mkEnableOption "cli file browser";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [yazi];

    programs.yazi = {
      enable = true;
    };
  };
}
