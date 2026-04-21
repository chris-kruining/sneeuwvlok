{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.development.rust;
in {
  options.${namespace}.development.rust = {
    enable = mkEnableOption "Enable rust development tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [];
  };
}
