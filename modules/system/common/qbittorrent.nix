{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.qbittorrent;
  UID = 888;
  GID = 888;
in
{
  options.services.qbittorrent = {
    enable = mkEnableOption (lib.mdDoc "qBittorrent headless");

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/qbittorrent";
      description = lib.mdDoc ''
        The directory where qBittorrent stores its data files.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "qbittorrent";
      description = lib.mdDoc ''
        User account under which qBittorrent runs.
      '';
    };

    group = mkOption {
      type = types.str;
      default = "qbittorrent";
      description = lib.mdDoc ''
        Group under which qBittorrent runs.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = lib.mdDoc ''
        qBittorrent web UI port.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Open services.qBittorrent.port to the outside network.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.qbittorrent-nox;
      defaultText = literalExpression "pkgs.qbittorrent-nox";
      description = lib.mdDoc ''
        The qbittorrent package to use.
      '';
    };
  };

  config = mkIf cfg.enable (let
    configFile = pkgs.writeText "qBittorrent.conf" ''
      [BitTorrent]
      Session\Port=53271
      Session\SSL\Port=45846
      Session\QueueingSystemEnabled=false
      Session\MaxUploads=-1
      Session\MaxUploadsPerTorrent=-1

      [Meta]
      MigrationVersion=8

      [Network]
      Cookies=@Invalid()

      [Preferences]
      WebUI\Port=5000
      WebUI\Username=admin
      WebUI\Password_PBKDF2="@ByteArray(Clgb2+ZyS3PDRVqtYpj0Ow==:kjN301CJife6g5ou8N2mk6ydQWPQIGgrTAWg5ByWCqAv0jDLphR/IaVQ1tu9KtA+il1udi48xSXZ3AUpjK/fRw==)"

      [RSS]
      AutoDownloader\DownloadRepacks=true
      AutoDownloader\SmartEpisodeFilter=s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"
    '';
  in {
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    systemd.tmpfiles.rules = [
      # https://www.mankier.com/5/tmpfiles.d
      "d '${cfg.dataDir}' 0700 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.dataDir}/__config' 0700 ${cfg.user} ${cfg.group} - -"
      "L+ '${cfg.dataDir}/__config/qBittorrent.conf' - - - - ${configFile}"
    ];

    systemd.services.qbittorrent = {
      description = "qBittorrent-nox service";
      documentation = [ "man:qbittorrent-nox(1)" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        ExecStartPre = let
          preStartScript = pkgs.writeScript "qbittorrent-run-prestart" ''
            #!${pkgs.bash}/bin/bash

            # Create data directory if it doesn't exist
            if ! test -d "$QBT_PROFILE"; then
              echo "Creating initial qBittorrent data directory in: $QBT_PROFILE"
              install -d -m 0755 -o "${cfg.user}" -g "${cfg.group}" "$QBT_PROFILE"
            fi
         '';
        in
          "!${preStartScript}";

        ExecStart = "${cfg.package}/bin/qbittorrent-nox";
      };

      environment = {
        QBT_PROFILE = cfg.dataDir;
        QBT_WEBUI_PORT = toString cfg.port;
      };
    };

    users.users = mkIf (cfg.user == "qbittorrent") {
      qbittorrent = {
        group = cfg.group;
        uid = UID;
      };
    };

    users.groups = mkIf (cfg.group == "qbittorrent") {
      qbittorrent = { gid = GID; };
    };
  });
}
