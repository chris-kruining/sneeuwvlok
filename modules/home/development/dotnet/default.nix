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

  # Microsoft's flake bumps its manifest well after a release, so the release is pinned here.
  # Drop this once eng/nix/versions.json upstream reaches this version.
  aspireVersion = "17.0.0";
  aspireRelease = rid: hash: {
    inherit rid hash;
    archiveName = "aspire-cli-${rid}-${aspireVersion}.tar.gz";
    url = "https://github.com/microsoft/aspire/releases/download/v${aspireVersion}/aspire-cli-${rid}-${aspireVersion}.tar.gz";
  };
  aspire-cli = inputs.aspire.packages.${system}.aspire-cli.override {
    manifest = {
      version = aspireVersion;
      releaseTag = "v${aspireVersion}";
      systems = {
        x86_64-linux = aspireRelease "linux-x64" "sha512-+SCLUxzDJKhhLR71e8qZFJAUk7QIavjrShgoLEpbazEkbLHOW61R8IqR+xZY1hQ2KHV2aq8DEdg+E2L31E8lOw==";
        aarch64-linux = aspireRelease "linux-arm64" "sha512-fljpZEhFMldsUFg3XeOa8nZ7czxZ9dZrVjqfSTYWH/atScRcXo7Fw5ailYpVEA7mxYYCFwzhDOoWGL09jMYUxQ==";
      };
    };
  };
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
      pkgs.dotnet-sdk_11
      aspire-cli
    ];
  };
}
