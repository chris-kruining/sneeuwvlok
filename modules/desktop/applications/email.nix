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
#     user.packages = attrValues {
#       inherit (pkgs) thunderbird;
#     };

    programs.thunderbird = {
      enable = true;
#       profiles.chris = {
#         isDefault = true;
#       };
    };

    hm.accounts.email.accounts = {
      kruining = {
        primary = true;
        address = "chris@kruinin.eu";
        realName = "Chris Kruining";
        imap = {
          host = "imap.kruining.eu";
          port = 993;
        };
        thunderbird = {
          enable = true;
          profiles = [ "chris" ];
        };
      };

      cgames = {
        primary = false;
        address = "chris@cgames.nl";
        realName = "Chris P Bacon";
        imap = {
          host = "imap.cgames.nl";
          port = 993;
        };
      };
    };
  };
}
