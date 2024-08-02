{ options, config, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.desktop.applications.email;
in
{
  options.modules.desktop.applications.email = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Enable email client (thunderbird)";
  };

  config = mkIf cfg.enable
  {
    user.packages = attrValues {
      inherit (pkgs) thunderbird;
    };

    accounts.email.account = {
      kruining = {
        primary = true;
        address = "chris@kruinin.eu";
        thunderbird.enable = true;
        realName = "Chris Kruining";
      };

      cgames = {
        primary = false;
        address = "chris@cgames.nl";
        thunderbird.enable = true;
        realName = "Chris P Bacon";
      };
    };
  };
}
