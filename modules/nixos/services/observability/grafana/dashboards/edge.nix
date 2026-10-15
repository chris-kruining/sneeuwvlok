# What comes in through caddy, per site
{
  lib,
  namespace,
  hostName,
  annotations,
}: let
  inherit (lib.${namespace}.grafana) dashboard prometheus prometheusNow prometheusTotal loki lokiTotal thresholds stat timeseries stacked table top logs variable mergeColumns override color;

  requests = ''caddy_http_request_duration_seconds_count{host=~"$site"}'';

  # The access logs of the selected sites, the stream already has a label `host` (the machine)
  access = fields: ''{job="caddy"} | json site="request.host"${lib.concatMapStrings (field: ", ${field}") fields} | site=~"$site"'';
in
  dashboard {
    uid = "${hostName}-edge";
    title = "Edge";
    tags = [hostName];
    inherit annotations;

    variables = [
      (variable "site" "Site" ''label_values(caddy_http_request_duration_seconds_count{host!="_other"}, host)'')
    ];

    rows = [
      [
        (stat {
          title = "Requests";
          w = 4;
          h = 4;
          targets = [(prometheusTotal "sum(increase(${requests}[$__range]))")];
          unit = "short";
          decimals = 0;
          thresholds = thresholds "text" [];
        })
        (stat {
          title = "Server errors";
          w = 4;
          h = 4;
          targets = [
            (prometheusTotal ''sum(increase(caddy_http_request_duration_seconds_count{host=~"$site", code=~"5.."}[$__range])) / sum(increase(${requests}[$__range])) or vector(0)'')
          ];
          unit = "percentunit";
          thresholds = thresholds "green" [[0.01 "orange"] [0.05 "red"]];
        })
        (stat {
          title = "Client errors";
          w = 4;
          h = 4;
          targets = [
            (prometheusTotal ''sum(increase(caddy_http_request_duration_seconds_count{host=~"$site", code=~"4.."}[$__range])) / sum(increase(${requests}[$__range])) or vector(0)'')
          ];
          unit = "percentunit";
          thresholds = thresholds "green" [[0.2 "orange"]];
        })
        (stat {
          title = "95% answered within";
          w = 4;
          h = 4;
          targets = [
            (prometheusTotal ''histogram_quantile(0.95, sum by (le) (rate(caddy_http_request_duration_seconds_bucket{host=~"$site"}[$__range])))'')
          ];
          unit = "s";
          thresholds = thresholds "green" [[1 "orange"] [5 "red"]];
        })
        (stat {
          title = "Sent";
          w = 4;
          h = 4;
          targets = [(prometheusTotal ''sum(increase(caddy_http_response_size_bytes_sum{host=~"$site"}[$__range]))'')];
          unit = "bytes";
          thresholds = thresholds "text" [];
        })
        (stat {
          title = "Sites up";
          w = 4;
          h = 4;
          targets = [(prometheusTotal "sum(probe_success) / count(probe_success)")];
          unit = "percentunit";
          thresholds = thresholds "red" [[1 "green"]];
        })
      ]

      {row = "Traffic";}
      [
        (stacked {
          title = "Requests per site";
          w = 12;
          targets = [(prometheus "sum by (host) (rate(${requests}[$__rate_interval]))" "{{ host }}")];
          unit = "reqps";
        })
        (stacked {
          title = "Responses by status";
          w = 12;
          targets = [
            (prometheus ''sum by (class) (label_replace(rate(${requests}[$__rate_interval]), "class", "''${1}xx", "code", "(.).*"))'' "{{ class }}")
          ];
          unit = "reqps";
          overrides = [
            (color "2xx" "green")
            (color "3xx" "blue")
            (color "4xx" "orange")
            (color "5xx" "red")
          ];
        })
      ]
      [
        (timeseries {
          title = "95% answered within, per site";
          w = 12;
          targets = [
            (prometheus ''histogram_quantile(0.95, sum by (host, le) (rate(caddy_http_request_duration_seconds_bucket{host=~"$site"}[$__rate_interval])))'' "{{ host }}")
          ];
          unit = "s";
        })
        (stacked {
          title = "Sent per site";
          w = 12;
          targets = [
            (prometheus ''sum by (host) (rate(caddy_http_response_size_bytes_sum{host=~"$site"}[$__rate_interval]))'' "{{ host }}")
          ];
          unit = "Bps";
        })
      ]

      {row = "Sites";}
      [
        (table {
          title = "Probes";
          description = "Every site, probed from here every 15 seconds";
          w = 24;
          h = 8;
          targets = [
            (prometheusNow "probe_success" "")
            (prometheusNow "probe_http_status_code" "")
            (prometheusNow "probe_duration_seconds" "")
            (prometheusNow "(probe_ssl_earliest_cert_expiry - time()) / 86400" "")
          ];
          transformations = mergeColumns {
            A = "Up";
            B = "Status";
            C = "Duration";
            D = "Certificate valid for (days)";
            instance = "Site";
          };
          overrides = [
            (override "Duration" {unit = "s";})
            (override "Certificate valid for (days)" {decimals = 0;})
          ];
        })
      ]

      {row = "Clients";}
      [
        (top "Client" "Requests" {
          title = "Busiest clients";
          w = 8;
          h = 10;
          targets = [
            (lokiTotal ''topk(15, sum by (client_ip) (count_over_time(${access ["client_ip=\"request.client_ip\""]} [$__range])))'' "{{ client_ip }}")
          ];
        })
        (top "Path" "Requests" {
          title = "Most requested missing paths";
          w = 8;
          h = 10;
          targets = [
            (lokiTotal ''topk(15, sum by (uri) (count_over_time(${access ["uri=\"request.uri\"" "status=\"status\""]} | status = 404 [$__range])))'' "{{ uri }}")
          ];
        })
        (top "User agent" "Requests" {
          title = "User agents";
          w = 8;
          h = 10;
          targets = [
            (lokiTotal ''topk(15, sum by (agent) (count_over_time(${access ["agent=`request.headers[\"User-Agent\"][0]`"]} [$__range])))'' "{{ agent }}")
          ];
        })
      ]

      {row = "Errors";}
      [
        (logs {
          title = "Server errors";
          w = 24;
          h = 12;
          targets = [(loki "${access ["status=\"status\""]} | status >= 500" "")];
        })
      ]
    ];
  }
