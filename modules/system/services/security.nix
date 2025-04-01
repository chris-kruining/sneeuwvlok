{ config, lib, pkgs, ... }:
let
inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  cfg = config.modules.services.auth;
in
{
  options.modules.services.security = {
    enable = mkEnableOption "Auth";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      vaultwarden
      vaultwarden-postgresql
    ];

    services.vaultwarden = {
      enable = true;
      dbBackend = "postgresql";

      config = {
        SIGNUPS_ALLOWED = false;
        DOMAIN = "https://passwords.kruining.eu";
      };
    };
  };
}
