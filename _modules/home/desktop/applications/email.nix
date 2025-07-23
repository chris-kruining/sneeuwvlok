{ options, config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.${user}.desktop.applications.email;
in
{
  options.modules.${user}.desktop.applications.email = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Enable email client (thunderbird)";
  };

  config = mkIf cfg.enable
  {
    programs.thunderbird = {
      enable = true;
    };

    home-manager.users.${user} = {
      home.packages = attrValues {
        inherit (pkgs) thunderbird;
      };

      accounts.email.accounts = {
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
  };
}
