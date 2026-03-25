{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.thunderbird;
in
{
  options.sneeuwvlok.application.thunderbird = {
    enable = mkEnableOption "enable thunderbird";
  };

  config = mkIf cfg.enable {
    programs.thunderbird = {
      enable = true;
      package = pkgs.thunderbird-latest;

        profiles.chris = {
        isDefault = true;
      };
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
}
