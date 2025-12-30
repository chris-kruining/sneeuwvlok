{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  system,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.${namespace}.services.media.jellyfin;
in {
  options.${namespace}.services.media.jellyfin = {
    enable = mkEnableOption "Enable jellyfin server";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
      mediainfo
      id3v2
      yt-dlp
    ];

    services = {
      # port is harcoded in nixpkgs module
      jellyfin = {
        enable = true;
        openFirewall = true;
        user = "media";
        group = "media";
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "jellyfin.kruining.eu".extraConfig = ''
            reverse_proxy http://[::1]:8096
          '';
        };
      };
    };

    systemd.services.jellyfin.serviceConfig.killSignal = lib.mkForce "SIGKILL";
  };
}
