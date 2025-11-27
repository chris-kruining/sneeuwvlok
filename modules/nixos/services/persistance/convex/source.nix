{ config, pkgs, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption mkPackageOption mkOption optional types;

  cfg = config.services.convex;

  default_user = "convex";
  default_group = "convex";
in
{
  options.services.convex = {
    enable = mkEnableOption "enable Convex (backend only for now)";

    package = mkPackageOption pkgs "convex" {};

    name = lib.mkOption {
      type = types.str;
      default = "convex";
      description = ''
        Name for the instance.
      '';
    };

    secret = lib.mkOption {
      type = types.str;
      default = "";
      description = ''
        Secret for the instance.
      '';
    };

    apiPort = mkOption {
      type = types.port;
      default = 3210;
      description = ''
        The TCP port to use for the API.
      '';
    };

    actionsPort = mkOption {
      type = types.port;
      default = 3211;
      description = ''
        The TCP port to use for the HTTP actions.
      '';
    };

    dashboardPort = mkOption {
      type = types.port;
      default = 6791;
      description = ''
        The TCP port to use for the Dashboard.
      '';
    };

    openFirewall = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to open ports in the firewall for the server.
      '';
    };

    user = lib.mkOption {
      type = types.str;
      default = default_user;
      description = ''
        As which user to run the service.
      '';
    };

    group = lib.mkOption {
      type = types.str;
      default = default_group;
      description = ''
        As which group to run the service.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.secret != "";
        message = ''
          No secret provided for convex
        '';
      }
    ];

    users = {
      users.${cfg.user} = {
        description = "System user for convex service";
        isSystemUser = true;
        group = cfg.group;
      };

      groups.${cfg.group} = {};
    };

    networking.firewall.allowedTCPPorts = optional cfg.openFirewall [ cfg.apiPort cfg.actionsPort cfg.dashboardPort ];
    
    environment.systemPackages = [ cfg.package ];

    systemd.services.convex = {
      description = "Convex Backend server";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin --instance-name ${cfg.name} --instance-secret ${cfg.secret}";
        Type = "notify";

        User = cfg.user;
        Group = cfg.group;

        RuntimeDirectory = "convex";
        RuntimeDirectoryMode = "0775";
        StateDirectory = "convex";
        StateDirectoryMode = "0775";
        Umask = "0077";

        CapabilityBoundingSet = "";
        NoNewPrivileges = true;

        # Sandboxing
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        LockPersonality = true;
      };
    };
  };
}
