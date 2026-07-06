{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.sneeuwvlok.development.dotnet;
in {
  options.sneeuwvlok.development.dotnet = {
    enable = mkEnableOption "Enable dotnet development tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [dotnet-sdk_10];
  };
}
