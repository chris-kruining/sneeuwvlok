{
  inputs,
  system,
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
    home.sessionVariables = {
      DOTNET_CLI_TELEMETRY_OPTOUT = "1";
      ASPIRE_CLI_TELEMETRY_OPTOUT = "1";
    };

    # aspire-cli is not in nixpkgs, it comes from microsoft's own flake
    home.packages = [
      pkgs.dotnet-sdk_10
      inputs.aspire.packages.${system}.aspire-cli
    ];
  };
}
