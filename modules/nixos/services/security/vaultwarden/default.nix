{ pkgs, config, lib, namespace, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.${namespace}.services.security.vaultwarden;
in
{
  options.${namespace}.services.security.vaultwarden = {
    enable = mkEnableOption "enable vaultwarden";
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
