{ config, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;

  user = "media";
  group = "media";
  directory = "/var/media";
in
{
  options.modules.services.media = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Media tools";
  };

  imports = let
    extras = fetchTarball {
      url = "https://github.com/onny/nixos-nextcloud-testumgebung/archive/fa6f062830b4bc3cedb9694c1dbf01d5fdf775ac.tar.gz";
      sha256 = "0gzd0276b8da3ykapgqks2zhsqdv4jjvbv97dsxg0hgrhb74z0fs";
    };
  in [
    "${extras}/nextcloud-extras.nix"
  ];

  config = mkIf config.modules.services.media.enable {
    environment.systemPackages = with pkgs; [
      podman-tui
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
      jellyseerr
      mediainfo
      id3v2
      yt-dlp
    ];

    users = {
      users.${user} = {
        isSystemUser = true;
        group = group;
      };
      groups.${group} = {};
    };

    systemd.tmpfiles.rules = [
      "d '${directory}/series' 0700 ${user} ${group} - -"
      "d '${directory}/movies' 0700 ${user} ${group} - -"
      "d '${directory}/music' 0700 ${user} ${group} - -"
      "d '${directory}/qbittorrent' 0700 ${user} ${group} - -"
      "d '${directory}/sabnzbd' 0700 ${user} ${group} - -"
      "d '${directory}/reiverr/config' 0700 ${user} ${group} - -"
      "d '${directory}/downloads/incomplete' 0700 ${user} ${group} - -"
      "d '${directory}/downloads/done' 0700 ${user} ${group} - -"
    ];

    services = let
      serviceConf = {
        enable = true;
        openFirewall = true;
        user = user;
        group = group;
      };
    in {
      jellyfin = serviceConf;
      radarr = serviceConf;
      sonarr = serviceConf;
      bazarr = serviceConf;
      lidarr = serviceConf;

      jellyseerr = {
        enable = true;
        openFirewall = true;
      };

      prowlarr = {
        enable = true;
        openFirewall = true;
      };

      qbittorrent = {
        enable = true;
        openFirewall = true;
        dataDir = "${directory}/qbittorrent";
        port = 5000;

        user = user;
        group = group;
      };

      sabnzbd = {
        enable = true;
        openFirewall = true;
        configFile = "${directory}/sabnzbd/config.ini";

        user = user;
        group = group;
      };

      caddy = {
        enable = true;
        virtualHosts = {
          "media.kruining.eu".extraConfig = ''
            import auth

            reverse_proxy http://127.0.0.1:9494
          '';
          "jellyfin.kruining.eu".extraConfig = ''
            reverse_proxy http://127.0.0.1:8096
          '';
          # "series.kruining.eu".extraConfig = ''
          #   reverse_proxy http://127.0.0.1:8989
          # '';
          # "movies.kruining.eu".extraConfig = ''
          #   reverse_proxy http://127.0.0.1:7878
          # '';
          # "indexer.kruining.eu".extraConfig = ''
          #   reverse_proxy http://127.0.0.1:9696
          # '';
          # "torrents.kruining.eu".extraConfig = ''
          #   reverse_proxy http://127.0.0.1:5000
          # '';
          # "usenet.kruining.eu".extraConfig = ''
          #   reverse_proxy http://127.0.0.1:8080
          # '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    modules.virtualisation.podman.enable = true;

    virtualisation = {
      oci-containers = {
        backend = "podman";

        containers = {
          flaresolverr = {
            image = "flaresolverr/flaresolverr";
            autoStart = true;
            ports = [ "127.0.0.1:8191:8191" ];
          };

          reiverr = {
            image = "ghcr.io/aleksilassila/reiverr:v2.2.0";
            autoStart = true;
            ports = [ "127.0.0.1:9494:9494" ];
            volumes = [ "${directory}/reiverr/config:/config" ];
          };
        };
      };
    };

    systemd.services.jellyfin.serviceConfig.killSignal = lib.mkForce "SIGKILL";
  };
}
