{ inputs, config, options, lib, pkgs, user, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge;
in
{
  options.modules.${user}.develop.dotnet = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption ".NET developmnt";
  };

  config = mkIf config.modules.${user}.develop.dotnet.enable {
    user.packages = attrValues {
      inherit (pkgs) dotnet-sdk_8;
    };
  };
}
