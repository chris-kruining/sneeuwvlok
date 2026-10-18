{
  inputs,
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.development.dotnet;
in {
  options.${namespace}.development.dotnet = {
    enable = mkEnableOption "Enable dotnet development tools";
  };

  config = mkIf cfg.enable {
    # aspire-cli is not in nixpkgs, it comes from microsoft's own flake
    home.packages = [
      pkgs.dotnet-sdk_10
      inputs.aspire.packages.${pkgs.stdenv.hostPlatform.system}.aspire-cli
    ];
  };
}
