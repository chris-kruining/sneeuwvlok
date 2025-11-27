{ config, pkgs, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.persistance.convex;
in
{
  imports = [ ./source.nix ];

  options.${namespace}.services.persistance.convex = {
    enable = mkEnableOption "enable Convex";
  };

  config = mkIf cfg.enable {
    services.convex = {
      enable = true;
      package = pkgs.${namespace}.convex;
      secret = "ThisIsMyAwesomeSecret";
    };
  };
}
