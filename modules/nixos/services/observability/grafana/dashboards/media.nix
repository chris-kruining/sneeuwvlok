# The servarr apps: the library, what they grab and import, and the indexers of prowlarr
{
  lib,
  namespace,
  hostName,
  annotations,
  arrs,
}: let
  inherit (lib) concatStringsSep elem optionals;
  inherit (lib.${namespace}.grafana) dashboard prometheus prometheusNow prometheusTotal loki thresholds stat timeseries bars bargauge table logs hide;

  has = app: elem app arrs;
  # The apps that grab and import, prowlarr only searches
  libraries = lib.filter (app: app != "prowlarr") arrs;

  units = apps: ''unit=~"(${concatStringsSep "|" apps}).service"'';
  metrics = apps: suffix: ''{__name__=~"(${concatStringsSep "|" apps})_${suffix}"}'';

  grabs = ''{${units libraries}} |= "DownloadService:" |= "sent to"'';
  imports = ''{${units libraries}} |~ `Import\w*: |FileMovingService: ` !~ `Importing 0 |Existing\w+Importer`'';

  count = title: expr:
    stat {
      inherit title;
      w = 3;
      h = 4;
      targets = [(prometheusTotal expr)];
      thresholds = thresholds "text" [];
    };
in
  dashboard {
    uid = "${hostName}-media";
    title = "Media";
    tags = [hostName];
    time = "now-7d";

    annotations =
      annotations
      ++ [
        (lib.${namespace}.grafana.annotation "Grabs" "green" grabs)
      ];

    rows = [
      (optionals (has "radarr") [
          (count "Movies" "radarr_movie_total")
          (count "Movies missing" "radarr_movie_missing_total")
        ]
        ++ optionals (has "sonarr") [
          (count "Series" "sonarr_series_total")
          (count "Episodes missing" "sonarr_episode_missing_total")
        ]
        ++ optionals (has "lidarr") [
          (count "Artists" "lidarr_artists_total")
          (count "Albums missing" "lidarr_albums_missing_total")
        ]
        ++ optionals (has "prowlarr") [
          (count "Indexers" "prowlarr_indexer_enabled_total")
        ])

      [
        (table {
          title = "Health";
          description = "The problems the apps report about themselves";
          w = 16;
          targets = [(prometheusNow (metrics arrs "system_health_issues") "")];
          transformations = hide ["Time" "Value" "__name__" "instance" "url" "wikiurl"];
        })
        (table {
          title = "Queue";
          w = 8;
          targets = [
            (prometheusNow "sum by (job, download_state, download_status) (${metrics libraries "queue_total"})" "")
          ];
          transformations = hide ["Time"];
        })
      ]

      {row = "Downloads";}
      [
        (bars {
          title = "Grabs";
          w = 12;
          h = 7;
          targets = [(loki "sum by (unit) (count_over_time(${grabs} [$__auto]))" "{{ unit }}")];
          min = 0;
        })
        (bars {
          title = "Imports";
          w = 12;
          h = 7;
          targets = [(loki "sum by (unit) (count_over_time(${imports} [$__auto]))" "{{ unit }}")];
          min = 0;
        })
      ]
      [
        (bargauge {
          title = "Space left";
          w = 8;
          h = 7;
          targets = [(prometheus (metrics libraries "rootfolder_freespace_bytes") "{{ path }}")];
          unit = "bytes";
          min = 0;
          thresholds = thresholds "red" [[(100 * 1024 * 1024 * 1024) "orange"] [(500 * 1024 * 1024 * 1024) "green"]];
        })
        (logs {
          title = "Grabbed";
          w = 16;
          h = 7;
          targets = [(loki grabs "")];
        })
      ]
    ]
    ++ optionals (has "prowlarr") [
      {row = "Indexers";}
      [
        (bars {
          title = "Queries";
          w = 8;
          h = 7;
          targets = [
            (prometheus "sum by (indexer) (increase(prowlarr_indexer_queries_total[$__rate_interval])) > 0" "{{ indexer }}")
          ];
          min = 0;
        })
        (bars {
          title = "Failed queries";
          w = 8;
          h = 7;
          targets = [
            (prometheus "sum by (indexer) (increase(prowlarr_indexer_failed_queries_total[$__rate_interval])) > 0" "{{ indexer }}")
          ];
          min = 0;
        })
        (timeseries {
          title = "Response time";
          w = 8;
          h = 7;
          targets = [(prometheus "prowlarr_indexer_average_response_time_ms" "{{ indexer }}")];
          unit = "ms";
        })
      ]
    ]
    ++ [
      {row = "Logs";}
      [
        (logs {
          title = "Warnings and errors";
          w = 24;
          h = 12;
          targets = [(loki ''{${units arrs}} |~ `^\[(Warn|Error|Fatal)\]`'' "")];
        })
      ]
    ];
  }
