{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.development.go;
in {
  options.${namespace}.development.go = {
    enable = mkEnableOption "Enable go development tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [go gopls delve];
  };
}
