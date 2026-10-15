{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkEnableOption mkIf mkOption optionals types;

  cfg = config.${namespace}.services.observability.security;
  services = config.${namespace}.services;

  rule = alert: expr: for: severity: summary: {
    inherit alert expr for;
    labels.severity = severity;
    annotations.summary = summary;
  };

  # A login over ssh is only expected from these networks
  outside = cfg.internalNetworks |> map (network: ''| addr != ip("${network}")'') |> lib.join " ";

  # Users allowed to log in over ssh, whose authorized keys are watched
  sshUsers = config.services.openssh.settings.AllowUsers or null |> (users: if users == null then ["root"] else users);
  # Not every user is declared (chris isn't on ulmo)
  home = user:
    config.users.users.${user}.home or (
      if user == "root"
      then "/root"
      else "/home/${user}"
    );
  sshDirectories = sshUsers |> map (user: "${home user}/.ssh");

  # Paths scanners try, a 200 with content for one of them means something is exposed that shouldn't be
  scannerPaths = ''(?i).*/(\.env($|[/?])|\.git/config|wp-login\.php|phpmyadmin|\.aws/credentials|\.ssh/|server-status|actuator/env).*'';

  # Zitadel doesn't log failed logins, it only stores them as events
  authEvents = [
    "user.human.password.check.succeeded"
    "user.human.password.check.failed"
    "user.human.mfa.otp.check.failed"
    "user.human.mfa.u2f.token.check.failed"
    "user.human.passwordless.token.check.failed"
    "user.locked"
  ];

  sqlPort = 9029;
in {
  options.${namespace}.services.observability.security = {
    enable = mkEnableOption "alerts on suspicious logins, traffic and changes";

    internalNetworks = mkOption {
      type = types.listOf types.str;
      default = ["192.168.0.0/16"];
      description = ''
        Networks logins over ssh are expected from, the local network and the vpn.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Changes to the authorized keys, the kernel's audit records end up in the journal
    security.audit = {
      enable = true;
      rules =
        (sshDirectories ++ ["/etc/ssh/authorized_keys.d"])
        |> map (directory: "-w ${directory} -p wa -k ssh_keys");
    };

    services.prometheus = {
      exporters.sql = mkIf services.authentication.zitadel.enable {
        enable = true;
        listenAddress = "[::1]";
        port = sqlPort;
        configuration.jobs.zitadel = {
          interval = "1m";
          connections = ["postgres:///zitadel?host=/run/postgresql&sslmode=disable"];
          queries.auth_events = {
            help = "Authentication events of zitadel, by type";
            labels = ["event_type"];
            values = ["total"];
            # Every type gets a row, also before it happened for the first time
            query = ''
              select t.event_type, count(e.event_type) as total
              from (values ${authEvents |> map (event: "('${event}')") |> lib.join ", "}) as t(event_type)
              left join eventstore.events2 e on e.event_type = t.event_type
              group by t.event_type
            '';
          };
        };
      };

      scrapeConfigs = optionals services.authentication.zitadel.enable [
        {
          job_name = "sql";
          static_configs = [
            {targets = ["[::1]:${toString sqlPort}"];}
          ];
        }
      ];
    };

    # Like the postgres exporter, it reads the database as the local superuser
    systemd.services.prometheus-sql-exporter.serviceConfig = mkIf services.authentication.zitadel.enable {
      User = lib.mkForce "postgres";
      DynamicUser = lib.mkForce false;
    };

    ${namespace}.services.observability = {
      alertmanager.rules = [
        {
          name = "security";
          rules =
            optionals services.authentication.zitadel.enable [
              (rule "ZitadelLoginFailures"
                ''sum(delta(sql_auth_events{event_type=~".+\\.check\\.failed"}[15m])) > 3''
                "0m" "warning"
                "{{ $value | printf \"%.0f\" }} failed logins on zitadel in the last 15 minutes")

              (rule "ZitadelUserLocked"
                ''delta(sql_auth_events{event_type="user.locked"}[15m]) > 0''
                "0m" "critical"
                "Zitadel locked a user after too many failed logins")
            ]
            ++ [
              (rule "RequestSpike"
                ''
                  sum by (host) (rate(caddy_http_requests_total[10m])) > 10 * sum by (host) (rate(caddy_http_requests_total[1d]))
                  and sum by (host) (rate(caddy_http_requests_total[10m])) > 1
                ''
                "10m" "warning"
                "{{ $labels.host }} gets ten times its usual amount of requests")

              (rule "EgressUnusual"
                ''
                  rate(node_network_transmit_bytes_total{device!~"lo|veth.*|podman.*"}[15m]) > 5 * rate(node_network_transmit_bytes_total{device!~"lo|veth.*|podman.*"}[1d])
                  and rate(node_network_transmit_bytes_total{device!~"lo|veth.*|podman.*"}[15m]) > 20e6
                ''
                "15m" "warning"
                "{{ $labels.device }} sends {{ $value | humanize }}B/s, five times more than usual")

              (rule "ConntrackAlmostFull"
                "node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.8"
                "5m" "warning"
                "The connection tracking table is {{ $value | humanizePercentage }} full")
            ];
        }
      ];

      loki.rules = [
        {
          name = "logins";
          rules =
            [
              (rule "SshLoginFailures"
                ''sum by (host) (count_over_time({unit="sshd.service"} |~ `Failed (password|publickey)|[Ii]nvalid user|authenticating user .* \[preauth\]|maximum authentication attempts|not allowed because` [10m])) > 5''
                "0m" "warning"
                "{{ $value }} lines about failed ssh logins in the last 10 minutes (about two per attempt), ssh is only reachable over the vpn")

              (rule "SshLoginFromOutside"
                ''sum by (host, user, addr) (count_over_time({unit="sshd.service"} |= "Accepted" | regexp `Accepted \S+ for (?P<user>\S+) from (?P<addr>\S+) port` ${outside} [10m])) > 0''
                "0m" "critical"
                "{{ $labels.user }} logged in over ssh from {{ $labels.addr }}, which is neither the local network nor the vpn")

              (rule "SudoAuthenticationFailure"
                ''sum by (host) (count_over_time({identifier="sudo"} |~ `authentication failure|incorrect password attempt` [10m])) > 0''
                "0m" "warning"
                "Someone entered a wrong password for sudo")
            ]
            ++ optionals services.home-automation.home-assistant.enable [
              (rule "HomeAssistantLoginFailures"
                ''sum by (addr) (count_over_time({unit="home-assistant.service"} |= "invalid authentication" | regexp `\((?P<addr>[0-9a-fA-F:.]+)\)\. Requested URL` [15m])) > 3''
                "0m" "warning"
                "{{ $value }} failed logins on home assistant from {{ $labels.addr }}")
            ]
            ++ optionals services.security.vaultwarden.enable [
              (rule "VaultwardenLoginFailures"
                ''sum(count_over_time({unit="vaultwarden.service"} |~ `\(login\) POST /identity/connect/token => 4\d\d|Username or password is incorrect` [15m])) > 3''
                "0m" "warning"
                "{{ $value }} failed logins on vaultwarden in the last 15 minutes")
            ]
            ++ optionals services.media.jellyfin.enable [
              (rule "JellyfinLoginFailures"
                ''sum(count_over_time({unit="jellyfin.service"} |~ `Authentication request for .* has been denied` [15m])) > 3''
                "0m" "warning"
                "{{ $value }} failed logins on jellyfin in the last 15 minutes")
            ]
            ++ optionals services.development.forgejo.enable [
              (rule "ForgejoLoginFailures"
                ''sum(count_over_time({unit="forgejo.service"} |= "Failed authentication attempt" [15m])) > 3''
                "0m" "warning"
                "{{ $value }} failed logins on forgejo in the last 15 minutes")
            ]
            ++ optionals services.observability.grafana.enable [
              (rule "GrafanaLoginFailures"
                ''sum(count_over_time({unit="grafana.service"} |~ `(?i)invalid username or password` [15m])) > 3''
                "0m" "warning"
                "{{ $value }} failed logins on grafana in the last 15 minutes")
            ];
        }

        {
          name = "traffic";
          rules = [
            (rule "ClientErrorFlood"
              ''sum by (client_ip, vhost) (count_over_time({job="caddy"} | json client_ip="request.client_ip", status="status" | status >= 400 | status < 500 [5m])) > 50''
              "0m" "warning"
              "{{ $labels.client_ip }} caused {{ $value }} client errors on {{ $labels.vhost }} in 5 minutes")

            (rule "AuthenticationFailureFlood"
              ''sum by (client_ip, vhost) (count_over_time({job="caddy"} | json client_ip="request.client_ip", status="status" | status =~ "401|403" [10m])) > 20''
              "0m" "warning"
              "{{ $labels.client_ip }} was refused {{ $value }} times by {{ $labels.vhost }} in 10 minutes")

            (rule "ScannerProbe"
              ''sum by (client_ip) (count_over_time({job="caddy"} | json client_ip="request.client_ip", uri="request.uri" | uri =~ `${scannerPaths}` [10m])) > 5''
              "0m" "info"
              "{{ $labels.client_ip }} is probing for exposed files")

            (rule "ScannerHit"
              ''sum by (vhost, uri) (count_over_time({job="caddy"} | json uri="request.uri", status="status", size="size" | uri =~ `${scannerPaths}` | status = 200 | size > 0 [10m])) > 0''
              "0m" "warning"
              "{{ $labels.vhost }} served {{ $labels.uri }}, which scanners look for, check that it isn't exposed")
          ];
        }

        {
          name = "integrity";
          rules = [
            (rule "SystemSwitched"
              ''sum by (host) (count_over_time({job="journal"} |= "finished switching to system configuration" [5m])) > 0''
              "0m" "info"
              "A new system configuration was activated, if that wasn't a deploy of yours find out who did")

            (rule "SshKeysChanged"
              ''sum by (host) (count_over_time({transport="audit"} |= `key="ssh_keys"` [5m])) > 0''
              "0m" "warning"
              "The authorized ssh keys changed, if you didn't change them yourself someone else may have access")
          ];
        }
      ];
    };
  };
}
