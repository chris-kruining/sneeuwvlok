{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.shell.toolset.bat;
in {
  options.sneeuwvlok.shell.toolset.bat = {
    enable = mkEnableOption "cat replacement";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [bat];

    programs.bat = {
      enable = true;
    };
  };
}
