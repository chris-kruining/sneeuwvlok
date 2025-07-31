{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.development.dotnet;
in
{
  options.${namespace}.development.dotnet = {
    enable = mkEnableOption "Enable dotnet development tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ dotnet-sdk_8 ];
  };
}
