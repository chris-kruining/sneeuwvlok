{
  config,
  options,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.services.virtualisation.podman;
in {
  options.sneeuwvlok.services.virtualisation.podman = {
    enable = mkEnableOption "enable podman";
  };

  config = mkIf cfg.enable {
    virtualisation = {
      containers.enable = true;
      oci-containers.backend = "podman";

      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };
  };
}
