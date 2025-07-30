{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.thunderbird;
in
{
  options.${namespace}.application.thunderbird = {
    enable = mkEnableOption "enable thunderbird";
  };

  config = mkIf cfg.enable {
    # home.packages = with pkgs; [ thunderbird ];

    # programs.thunderbird = {
    #   enable = true;
    # };

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
}
