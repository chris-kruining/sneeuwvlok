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
    programs.thunderbird = {
      enable = true;
      package = pkgs.thunderbird-latest;

      profiles.${config.snowfallorg.user.name} = {
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
          profiles = [ config.snowfallorg.user.name ];
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
