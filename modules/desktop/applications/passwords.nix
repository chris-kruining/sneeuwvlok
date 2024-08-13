{ options, config, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.desktop.applications.passwords;
in
{
  options.modules.desktop.applications.passwords = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Enable password manager (bitwarden)";
  };

  config = mkIf cfg.enable
  {
    user.packages = attrValues {
      inherit (pkgs) bitwarden-desktop;
    };
  };
}
