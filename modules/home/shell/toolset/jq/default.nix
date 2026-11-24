{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.shell.toolset.jq;
in
{
  options.${namespace}.shell.toolset.jq = {
    enable = mkEnableOption "json/yaml tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ jq yq ];
  };
}
