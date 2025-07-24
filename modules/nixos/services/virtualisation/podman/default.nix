{ config, options, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.virtualisation.podman;
in
{
  options.${namespace}.services.virtualisation.podman = {
    enable = mkEnableOption "enable podman";
  };

  config = mkIf cfg.enable {
    virtualisation = {
      containers.enable = true;

      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };
  };
}
