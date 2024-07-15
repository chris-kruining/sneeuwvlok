{ config, pkgs, lib, sensitive, ... }:
{
  imports = [
    ../common/qbittorrent.nix
  ];

  environment.systemPackages = with pkgs; [
    podman-tui
    jellyfin
    jellyseerr
    mediainfo
    authelia
  ];

  users = {
    groups = {
      "jellyfin" = {};
    };
    users = {
      "sonarr".extraGroups = [ "jellyfin" ];
      "radarr".extraGroups = [ "jellyfin" ];
    };
  };

  services = {
    jellyfin = {
      enable = true;
      openFirewall = true;
      group = "jellyfin";
    };

    radarr = {
      enable = true;
      openFirewall = true;
      group = "jellyfin";
    };

    sonarr = {
      enable = true;
      openFirewall = true;
      group = "jellyfin";
    };

    bazarr = {
      enable = true;
      openFirewall = true;
      group = "jellyfin";
    };

    lidarr = {
      enable = true;
      openFirewall = true;
      group = "jellyfin";
    };

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
      dataDir = "/var/media/qbittorrent";
      port = 58080;

      user = "qbittorrent";
      group = "jellyfin";
    };

    sabnzbd = {
      enable = true;
      openFirewall = true;
      configFile = "/var/media/sabnzbd/config.ini";

      user = "sabnzbd";
      group = "jellyfin";
    };

#    authelia = {
#      enable = true;
#    };
    
    caddy = {
      enable = true;
      virtualHosts = {
#        "movies.kruining.eu".extraConfig = ''
#          reverse_proxy http://127.0.0.1:8989
#        '';
#        "series.kruining.eu".extraConfig = ''
#          reverse_proxy http://127.0.0.1:7878
#        '';
        "http://media.kruining.eu".extraConfig = ''
          basicauth {
            chris $2a$12$JrsmxrEJj2wLMdcFmEHbWeMJF9gWH/fnE/1Zv67cKvBtq4E4xsSEe
          }
          reverse_proxy http://127.0.0.1:9494
        '';
        "https://media.kruining.eu".extraConfig = ''
          basicauth {
            chris $2a$12$JrsmxrEJj2wLMdcFmEHbWeMJF9gWH/fnE/1Zv67cKvBtq4E4xsSEe
          }
          reverse_proxy http://127.0.0.1:9494
        '';
      };
    };
  };

  virtualisation = {
    containers.enable = true;

    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    oci-containers = {
      backend = "podman";

      containers = {
        flaresolverr = {
          image = "flaresolverr/flaresolverr";
          autoStart = true;
          ports = [ "127.0.0.1:8191:8191" ];
        };
        
        homarr = {
          image = "ghcr.io/ajnart/homarr:latest";
          autoStart = true;
          ports = [ "127.0.0.1:7575:7575" ];
        };

        reiverr = {
          image = "ghcr.io/aleksilassila/reiverr:v2.0.0-alpha.5";
          autoStart = true;
          ports = [ "127.0.0.1:9494:9494" ];
          volumes = [ "/var/media/reiverr/config:/config" ];
        };
      };
    };
  };

  # Config file for nabnzbd
#  environment.etc."nabnzbd.ini" = {
#    mode = "0775"
#    text = ''
#      host = 127.0.0.1
#      port = 9595
#    '';
#  };

  # Open firewall for caddy
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  systemd.services.jellyfin.serviceConfig.killSignal = lib.mkForce "SIGKILL";
}
