{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.shell.toolset.yazi;
in {
  options.${namespace}.shell.toolset.yazi = {
    enable = mkEnableOption "cli file browser";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [yazi];

    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
    };
  };
}
