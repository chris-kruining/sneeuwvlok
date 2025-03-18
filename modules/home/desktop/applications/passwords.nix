{ options, config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.${user}.desktop.applications.passwords;
in
{
  options.modules.${user}.desktop.applications.passwords = let
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
