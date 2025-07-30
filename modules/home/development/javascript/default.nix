{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.development.javascript;
in
{
  options.${namespace}.development.javascript = {
    enable = mkEnableOption "Enable javascript development tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ bun nodejs nodePackages_latest.typescript-language-server ];
  };
}
