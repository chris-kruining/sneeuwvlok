# The state of the machine at a glance, the home dashboard
{
  lib,
  namespace,
  hostName,
  annotations,
}: let
  inherit (lib.${namespace}.grafana) dashboard prometheus prometheusTotal loki thresholds stat timeseries stacked bars bargauge table logs alertlist hide;

  filesystems = ''fstype=~"ext4|vfat|btrfs|xfs", mountpoint!="/nix/store"'';
  interfaces = ''device!~"lo|veth.*|podman.*|br-.*"'';
in
  dashboard {
    uid = "${hostName}-overview";
    title = "${hostName}";
    tags = [hostName];
    inherit annotations;

    rows = [
      [
        (stat {
          title = "Alerts";
          description = "Firing alerts, without the watchdog that always fires";
          w = 3;
          h = 4;
          targets = [
            (prometheusTotal ''sum(alertmanager_alerts{state="active"}) - count(ALERTS{alertname="Watchdog", alertstate="firing"})'')
          ];
          thresholds = thresholds "green" [[1 "orange"]];
        })
        (stat {
          title = "Up for";
          w = 3;
          h = 4;
          targets = [(prometheusTotal "time() - node_boot_time_seconds")];
          unit = "dtdurations";
          thresholds = thresholds "text" [];
        })
        (stat {
          title = "CPU";
          w = 3;
          h = 4;
          targets = [(prometheusTotal ''1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))'')];
          unit = "percentunit";
          thresholds = thresholds "green" [[0.7 "orange"] [0.9 "red"]];
        })
        (stat {
          title = "Memory";
          w = 3;
          h = 4;
          targets = [(prometheusTotal "1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes")];
          unit = "percentunit";
          thresholds = thresholds "green" [[0.8 "orange"] [0.9 "red"]];
        })
        (stat {
          title = "Failed units";
          w = 3;
          h = 4;
          targets = [(prometheusTotal ''count(node_systemd_unit_state{state="failed"} == 1) or vector(0)'')];
          thresholds = thresholds "green" [[1 "red"]];
        })
        (stat {
          title = "Sites up";
          w = 3;
          h = 4;
          targets = [(prometheusTotal "sum(probe_success) / count(probe_success)")];
          unit = "percentunit";
          thresholds = thresholds "red" [[1 "green"]];
        })
        (stat {
          title = "Last backup";
          w = 3;
          h = 4;
          targets = [(prometheusTotal ''time() - max(node_systemd_timer_last_trigger_seconds{name=~"(borgbackup-job-.+|postgresqlBackup)\\.timer"})'')];
          unit = "dtdurations";
          thresholds = thresholds "green" [[(26 * 3600) "red"]];
        })
        (stat {
          title = "First certificate to expire";
          w = 3;
          h = 4;
          targets = [(prometheusTotal "min(probe_ssl_earliest_cert_expiry) - time()")];
          unit = "dtdurations";
          thresholds = thresholds "red" [[(3 * 86400) "orange"] [(14 * 86400) "green"]];
        })
      ]

      [
        (alertlist {
          title = "Alerts";
          w = 12;
          h = 8;
        })
        (bargauge {
          title = "Filesystems";
          w = 12;
          h = 8;
          targets = [
            (prometheus "1 - node_filesystem_avail_bytes{${filesystems}} / node_filesystem_size_bytes{${filesystems}}" "{{ mountpoint }}")
          ];
          unit = "percentunit";
          min = 0;
          max = 1;
          thresholds = thresholds "green" [[0.85 "orange"] [0.95 "red"]];
        })
      ]

      {row = "Resources";}
      [
        (stacked {
          title = "CPU";
          w = 12;
          targets = [
            (prometheus ''sum by (mode) (rate(node_cpu_seconds_total{mode!="idle"}[$__rate_interval])) / scalar(count(node_cpu_seconds_total{mode="idle"}))'' "{{ mode }}")
          ];
          unit = "percentunit";
          min = 0;
        })
        (timeseries {
          title = "Memory";
          w = 12;
          targets = [
            (prometheus "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes" "used")
            (prometheus "node_memory_Cached_bytes + node_memory_Buffers_bytes" "cache")
            (prometheus "node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes" "swap")
            (prometheus "node_memory_MemTotal_bytes" "total")
          ];
          unit = "bytes";
          min = 0;
        })
      ]
      [
        (timeseries {
          title = "Network";
          description = "Received up, sent down";
          w = 8;
          targets = [
            (prometheus "rate(node_network_receive_bytes_total{${interfaces}}[$__rate_interval])" "{{ device }} in")
            (prometheus "-rate(node_network_transmit_bytes_total{${interfaces}}[$__rate_interval])" "{{ device }} out")
          ];
          unit = "Bps";
        })
        (timeseries {
          title = "Disks";
          description = "Read up, written down";
          w = 8;
          targets = [
            (prometheus "rate(node_disk_read_bytes_total[$__rate_interval])" "{{ device }} read")
            (prometheus "-rate(node_disk_written_bytes_total[$__rate_interval])" "{{ device }} written")
          ];
          unit = "Bps";
        })
        (timeseries {
          title = "Load";
          w = 8;
          targets = [
            (prometheus "node_load1" "1m")
            (prometheus "node_load15" "15m")
            (prometheus ''count(node_cpu_seconds_total{mode="idle"})'' "cpus")
          ];
          min = 0;
        })
      ]
      [
        (timeseries {
          title = "Disk temperature";
          w = 8;
          h = 7;
          targets = [
            (prometheus ''smartctl_device_temperature{temperature_type="current"}'' "{{ device }}")
          ];
          unit = "celsius";
          thresholds = thresholds "green" [[55 "red"]];
        })
        (bargauge {
          title = "Disk wear";
          description = "The part of its rated write endurance a disk used";
          w = 8;
          h = 7;
          targets = [(prometheus "smartctl_device_percentage_used / 100" "{{ device }}")];
          unit = "percentunit";
          min = 0;
          max = 1;
          thresholds = thresholds "green" [[0.8 "orange"]];
        })
        (timeseries {
          title = "Filesystem space left";
          w = 8;
          h = 7;
          targets = [
            (prometheus "node_filesystem_avail_bytes{${filesystems}}" "{{ mountpoint }}")
          ];
          unit = "bytes";
          min = 0;
        })
      ]

      {row = "Services";}
      [
        (table {
          title = "Failed units";
          w = 8;
          targets = [
            (prometheus ''node_systemd_unit_state{state="failed"} == 1'' "" // {instant = true; range = false; format = "table";})
          ];
          transformations = hide ["Time" "Value" "__name__" "instance" "job" "state" "type"];
        })
        (bars {
          title = "Restarts";
          w = 16;
          targets = [
            (prometheus "sum by (name) (increase(node_systemd_service_restart_total[$__rate_interval])) > 0" "{{ name }}")
          ];
          min = 0;
        })
      ]

      {row = "Logs";}
      [
        (bars {
          title = "Errors per unit";
          w = 24;
          h = 7;
          targets = [
            (loki ''sum by (unit) (count_over_time({job="journal", level="error"} [$__auto]))'' "{{ unit }}")
          ];
          min = 0;
        })
      ]
      [
        (logs {
          title = "Errors";
          w = 24;
          h = 12;
          targets = [(loki ''{job="journal", level="error"}'' "")];
        })
      ]
    ];
  }
