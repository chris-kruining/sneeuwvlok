{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.persistance.postgresql;
in {
  options.${namespace}.services.persistance.postgresql = {
    enable = mkEnableOption "Postgresql";
  };

  # Access db with `psql -U postgres`
  config = mkIf cfg.enable {
    services = {
      postgresql = {
        enable = true;
        authentication = ''
          # Generated file, do not edit!
          # TYPE  DATABASE  USER  ADDRESS       METHOD
          local   all       all                 trust
          host    all       all   127.0.0.1/32  trust
          host    all       all   ::1/128       trust
        '';
      };
    };
  };
}
