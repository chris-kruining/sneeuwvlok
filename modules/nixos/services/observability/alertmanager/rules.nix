# Prometheus alert rules of the machine itself and the services on it. `warning` goes to matrix, `critical` is mailed
# as well and is meant for what needs attention soon.
let
  rule = alert: expr: for: severity: summary: extra:
    {
      inherit alert expr for;
      labels.severity = severity;
      annotations.summary = summary;
    }
    // extra;

  # Real filesystems, not the virtual ones
  filesystems = ''fstype=~"ext4|vfat|btrfs|xfs"'';

  backups = ''borgbackup-job-.+|postgresqlBackup'';
in [
  {
    name = "host";
    rules = [
      (rule "FilesystemAlmostFull"
        "100 * (1 - node_filesystem_avail_bytes{${filesystems}} / node_filesystem_size_bytes{${filesystems}}) > 85"
        "15m" "warning"
        "{{ $labels.mountpoint }} is {{ $value | printf \"%.0f\" }}% full" {})

      (rule "FilesystemFull"
        "100 * (1 - node_filesystem_avail_bytes{${filesystems}} / node_filesystem_size_bytes{${filesystems}}) > 95"
        "5m" "critical"
        "{{ $labels.mountpoint }} is {{ $value | printf \"%.0f\" }}% full" {})

      # Extrapolates the last 6 hours, only for filesystems that are not mostly empty to begin with
      (rule "FilesystemFillingUp"
        ''
          predict_linear(node_filesystem_avail_bytes{${filesystems}}[6h], 24 * 3600) < 0
          and 100 * (1 - node_filesystem_avail_bytes{${filesystems}} / node_filesystem_size_bytes{${filesystems}}) > 50
        ''
        "1h" "warning"
        "{{ $labels.mountpoint }} fills up within a day at the current rate" {})

      # The nix store is read only by design
      (rule "FilesystemReadOnly"
        ''node_filesystem_readonly{${filesystems}, mountpoint!="/nix/store"} == 1''
        "5m" "critical"
        "{{ $labels.mountpoint }} is mounted read only, usually because of filesystem errors" {})

      (rule "DiskFailing"
        "smartctl_device_smart_status == 0"
        "0m" "critical"
        "SMART of {{ $labels.device }} reports the disk is failing" {})

      (rule "DiskSectorsFailing"
        ''increase(smartctl_device_attribute{attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable", attribute_value_type="raw"}[1d]) > 0''
        "0m" "warning"
        "{{ $labels.device }} has new {{ $labels.attribute_name }} sectors" {})

      (rule "DiskWornOut"
        "smartctl_device_percentage_used > 80"
        "0m" "warning"
        "{{ $labels.device }} used {{ $value }}% of its rated write endurance" {})

      (rule "DiskTooHot"
        ''smartctl_device_temperature{temperature_type="current"} > 55''
        "15m" "warning"
        "{{ $labels.device }} is {{ $value }}°C" {})

      (rule "MemoryLow"
        "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1"
        "15m" "warning"
        "Only {{ $value | humanizePercentage }} of the memory is available" {})

      (rule "OutOfMemoryKill"
        "increase(node_vmstat_oom_kill[15m]) > 0"
        "0m" "warning"
        "The kernel killed a process because it ran out of memory" {})

      (rule "LoadHigh"
        ''node_load15 / count without (cpu, mode) (node_cpu_seconds_total{mode="idle"}) > 2''
        "30m" "warning"
        "The load is {{ $value | printf \"%.1f\" }} per cpu for half an hour" {})

      (rule "ClockNotSynchronised"
        "node_timex_sync_status == 0"
        "15m" "warning"
        "The clock is not synchronised" {})

      (rule "Rebooted"
        "time() - node_boot_time_seconds < 600"
        "0m" "info"
        "The machine booted {{ $value | humanizeDuration }} ago" {})
    ];
  }

  {
    name = "services";
    rules = [
      # Failed backups have their own alert
      (rule "UnitFailed"
        ''node_systemd_unit_state{state="failed", name!~"(${backups})\\.service"} == 1''
        "5m" "warning"
        "{{ $labels.name }} failed" {})

      (rule "UnitRestartLoop"
        "increase(node_systemd_service_restart_total[30m]) > 3"
        "0m" "warning"
        "{{ $labels.name }} restarted {{ $value | printf \"%.0f\" }} times in half an hour" {})

      (rule "TargetDown"
        "up == 0"
        "5m" "warning"
        "Prometheus can't scrape {{ $labels.job }} ({{ $labels.instance }})" {})
    ];
  }

  {
    name = "edge";
    rules = [
      (rule "SiteDown"
        "probe_success == 0"
        "5m" "warning"
        "{{ $labels.instance }} is down" {})

      (rule "SiteDownLong"
        "probe_success == 0"
        "1h" "critical"
        "{{ $labels.instance }} is down for an hour" {})

      (rule "CertificateExpiring"
        "(probe_ssl_earliest_cert_expiry - time()) / 86400 < 14"
        "1h" "warning"
        "The certificate of {{ $labels.instance }} expires in {{ $value | printf \"%.0f\" }} days, caddy should have renewed it by now" {})

      (rule "CertificateAlmostExpired"
        "(probe_ssl_earliest_cert_expiry - time()) / 86400 < 3"
        "0m" "critical"
        "The certificate of {{ $labels.instance }} expires in {{ $value | printf \"%.0f\" }} days" {})

      # Only for hosts with some traffic, a single failing request of a quiet host isn't worth an alert
      (rule "ServerErrors"
        ''
          sum by (host) (rate(caddy_http_request_duration_seconds_count{code=~"5.."}[10m]))
          / sum by (host) (rate(caddy_http_request_duration_seconds_count[10m])) > 0.05
          and sum by (host) (rate(caddy_http_request_duration_seconds_count[10m])) > 0.05
        ''
        "10m" "warning"
        "{{ $value | humanizePercentage }} of the requests to {{ $labels.host }} fail with a server error" {})
    ];
  }

  {
    name = "data";
    rules = [
      (rule "BackupFailed"
        ''node_systemd_unit_state{state="failed", name=~"(${backups})\\.service"} == 1''
        "0m" "critical"
        "Backup {{ $labels.name }} failed" {})

      # Both run daily
      (rule "BackupMissing"
        ''time() - node_systemd_timer_last_trigger_seconds{name=~"(${backups})\\.timer"} > 26 * 3600''
        "0m" "critical"
        "{{ $labels.name }} hasn't run for {{ $value | humanizeDuration }}" {})

      (rule "PostgresDown"
        "pg_up == 0"
        "2m" "critical"
        "Postgres is down" {})

      (rule "PostgresConnectionsRunningOut"
        "sum(pg_stat_activity_count) / max(pg_settings_max_connections) > 0.8"
        "10m" "warning"
        "Postgres uses {{ $value | humanizePercentage }} of its connections" {})
    ];
  }

  {
    name = "apps";
    rules = [
      # The *arrs report their own problems, only errors that last are worth an alert
      (rule "ArrHealthError"
        ''{__name__=~"(sonarr|radarr|lidarr|prowlarr)_system_health_issues", type="error"} == 1''
        "1h" "warning"
        "{{ $labels.job }}: {{ $labels.message }}" {
          annotations = {
            summary = "{{ $labels.job }}: {{ $labels.message }}";
            description = "{{ $labels.wikiurl }}";
          };
        })
    ];
  }
]
