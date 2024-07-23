{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;

  cfg = config.modules.virtualisation.podman;
in
{
  options.modules.virtualisation.podman = let
    inherit (lib.options) mkEnableOption;
  in
  {
    enable = mkEnableOption "enable podman";
  };

  config = mkIf options.modules.virtualisation.podman.enable {
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
