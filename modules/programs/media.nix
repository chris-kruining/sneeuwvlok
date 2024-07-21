{ config, pkgs, lib, sensitive, ... }:

with lib;

let
    user = "media";
    group = "media";
    directory = "/var/media";
in
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
    users."${user}" = {
      isSystemUser = true;
      group = group;
    };
    groups."${group}" = {};
  };

  system.activationScripts.var = mkForce ''
    install -d -m 0755 -o ${user} -g ${group} ${directory}/series
    install -d -m 0755 -o ${user} -g ${group} ${directory}/movies
    install -d -m 0755 -o ${user} -g ${group} ${directory}/qbittorrent
    install -d -m 0755 -o ${user} -g ${group} ${directory}/sabnzbd
    install -d -m 0755 -o ${user} -g ${group} ${directory}/reiverr/config
    install -d -m 0755 -o ${user} -g ${group} ${directory}/downloads/incomplete
    install -d -m 0755 -o ${user} -g ${group} ${directory}/downloads/done
  '';

  services = {
    jellyfin = {
      enable = true;
      openFirewall = true;
      user = user;
      group = group;
    };

    radarr = {
      enable = true;
      openFirewall = true;
      user = user;
      group = group;
    };

    sonarr = {
      enable = true;
      openFirewall = true;
      user = user;
      group = group;
    };

    bazarr = {
      enable = true;
      openFirewall = true;
      user = user;
      group = group;
    };

    lidarr = {
      enable = true;
      openFirewall = true;
      user = user;
      group = group;
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
      dataDir = "${directory}/qbittorrent";
      port = 5000;

      user = user;
      group = group;
    };

    sabnzbd = {
      enable = true;
      openFirewall = true;
      configFile = "${directory}/sabnzbd/config.ini";
      port = 5001;

      user = user;
      group = group;
    };

    caddy = {
      enable = true;
      virtualHosts = {
        "media.kruining.eu".extraConfig = ''
          #basicauth {
          #  chris $2a$12$JrsmxrEJj2wLMdcFmEHbWeMJF9gWH/fnE/1Zv67cKvBtq4E4xsSEe
          #}
          reverse_proxy http://127.0.0.1:9494
          tls internal
        '';
        "cloud.kruining.eu".extraConfig = ''
          basicauth {
            chris $2a$12$JrsmxrEJj2wLMdcFmEHbWeMJF9gWH/fnE/1Zv67cKvBtq4E4xsSEe
          }
          php_fastcgi unix//run/phpfpm/nextcloud.sock {
            env front_controller_active true
          }
          tls internal
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

        reiverr = {
          image = "ghcr.io/aleksilassila/reiverr:v2.0.0-alpha.6";
          autoStart = true;
          ports = [ "127.0.0.1:9494:9494" ];
          volumes = [ "${directory}/reiverr/config:/config" ];
        };
      };
    };
  };

  # Open firewall for caddy
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  systemd.services.jellyfin.serviceConfig.killSignal = lib.mkForce "SIGKILL";
}
