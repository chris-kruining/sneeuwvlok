{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.sneeuwvlok.shell.toolset.just;
in {
  options.sneeuwvlok.shell.toolset.just = {
    enable = mkEnableOption "version-control system";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [just gum];
  };
}
