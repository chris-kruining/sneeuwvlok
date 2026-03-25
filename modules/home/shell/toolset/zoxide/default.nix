{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.shell.toolset.zoxide;
in {
  options.sneeuwvlok.shell.toolset.zoxide = {
    enable = mkEnableOption "cd replacement";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [zoxide];

    programs.zoxide = {
      enable = true;
    };
  };
}
