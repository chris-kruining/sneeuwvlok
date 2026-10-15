# Logins, attacks and changes, with the same log selectors as the alerts
{
  lib,
  namespace,
  hostName,
  failedLogins,
  wafAnomalies,
  crowdsecDetections,
  sshKeyChanges,
  waf,
  crowdsec,
  zitadel,
}: let
  inherit (lib) optionals;
  inherit (lib.${namespace}.grafana) dashboard prometheus prometheusTotal loki lokiTotal thresholds stat timeseries bars top logs deploys;

  # Zero instead of no data when nothing happened
  total = expr: lokiTotal "${expr} or vector(0)" "";

  count = title: target: description:
    stat {
      inherit title description;
      w = 3;
      h = 4;
      targets = [target];
      decimals = 0;
      thresholds = thresholds "text" [];
    };

  # The lines of coraza's matches, as coraza wrote them
  wafMatches = ''{unit="caddy.service"} |= "Coraza:" | json msg="msg" | line_format `{{ .msg }}`'';
in
  dashboard {
    uid = "${hostName}-security";
    title = "Security";
    tags = [hostName];
    annotations = [deploys];

    rows = [
      ([
          (count "Failed ssh logins" (total "sum(count_over_time(${failedLogins.ssh} [$__range]))") "Log lines, about two per attempt")
          (count "Ssh logins" (total ''sum(count_over_time({unit="sshd.service"} |= "Accepted" [$__range]))'') null)
        ]
        ++ optionals zitadel [
          (count "Failed zitadel logins" (prometheusTotal ''sum(increase(sql_auth_events{event_type=~".+\\.check\\.failed"}[$__range]))'') null)
          (count "Zitadel logins" (prometheusTotal ''sum(increase(sql_auth_events{event_type="user.human.password.check.succeeded"}[$__range]))'') null)
        ]
        ++ optionals waf.enable [
          (count "Attacks on the waf" (total "sum(count_over_time(${wafAnomalies} [$__range]))") "Requests the OWASP rules regard as an attack")
        ]
        ++ optionals crowdsec [
          (count "CrowdSec detections" (total "sum(count_over_time(${crowdsecDetections} [$__range]))") null)
        ]
        ++ [
          (count "Refused requests" (total ''sum(count_over_time({job="caddy"} | json status="status" | status =~ "401|403" [$__range]))'') "Answered with 401 or 403")
          (count "Key changes" (total "sum(count_over_time(${sshKeyChanges} [$__range]))") "Changes to the authorized ssh keys")
        ])

      {row = "Logins";}
      [
        (bars {
          title = "Failed logins";
          w = 12;
          targets = lib.mapAttrsToList (app: selector: loki "sum(count_over_time(${selector} [$__auto]))" app) failedLogins;
          min = 0;
        })
        (if zitadel
          then
            bars {
              title = "Zitadel";
              w = 12;
              targets = [
                (prometheus "sum by (event_type) (increase(sql_auth_events[$__rate_interval])) > 0" "{{ event_type }}")
              ];
              min = 0;
            }
          else
            logs {
              title = "Sudo";
              w = 12;
              targets = [(loki ''{identifier="sudo"}'' "")];
            })
      ]
      [
        (logs {
          title = "Ssh";
          w = 24;
          h = 10;
          targets = [(loki ''{unit="sshd.service"} |~ `Accepted|Failed|[Ii]nvalid user|not allowed`'' "")];
        })
      ]
    ]
    ++ optionals (waf.enable || crowdsec) [
      {row = "Attacks";}
      [
        (bars {
          title = "Attacks";
          w = 24;
          h = 7;
          targets =
            optionals waf.enable [(loki "sum(count_over_time(${wafAnomalies} [$__auto]))" "waf")]
            ++ optionals crowdsec [(loki "sum(count_over_time(${crowdsecDetections} [$__auto]))" "crowdsec")];
          min = 0;
        })
      ]
      (optionals waf.enable [
          (top "Rule" "Matches" {
            title = "Waf rules";
            description = "The rules that matched, without the one adding up the score";
            w = 10;
            h = 10;
            targets = [
              (lokiTotal ''topk(20, sum by (id, rule) (count_over_time(${wafMatches} != `[id "949110"]` | regexp `\[id "(?P<id>\d+)"\].*?\[msg "(?P<rule>[^"]*)"\]` [$__range])))'' "{{ id }} {{ rule }}")
            ];
          })
          (top "Client" "Attacks" {
            title = "Waf clients";
            w = 7;
            h = 10;
            targets = [(lokiTotal "topk(20, sum by (client) (count_over_time(${wafAnomalies} [$__range])))" "{{ client }}")];
          })
        ]
        ++ optionals crowdsec [
          (top "Detection" "Times" {
            title = "CrowdSec";
            w = 7;
            h = 10;
            targets = [
              (lokiTotal "topk(20, sum by (addr, scenario) (count_over_time(${crowdsecDetections} [$__range])))" "{{ addr }} {{ scenario }}")
            ];
          })
        ])
    ]
    ++ optionals waf.enable [
      [
        (logs {
          title = "Waf";
          w = 24;
          h = 12;
          targets = [(loki wafMatches "")];
        })
      ]
    ]
    ++ [
      {row = "Network";}
      [
        (timeseries {
          title = "Sent";
          w = 8;
          h = 7;
          targets = [
            (prometheus ''rate(node_network_transmit_bytes_total{device!~"lo|veth.*|podman.*|br-.*"}[$__rate_interval])'' "{{ device }}")
          ];
          unit = "Bps";
        })
        (timeseries {
          title = "Tracked connections";
          w = 8;
          h = 7;
          targets = [(prometheus "node_nf_conntrack_entries / node_nf_conntrack_entries_limit" "in use")];
          unit = "percentunit";
          min = 0;
        })
        (bars {
          title = "Refused requests";
          w = 8;
          h = 7;
          targets = [
            (loki ''sum by (vhost) (count_over_time({job="caddy"} | json status="status" | status =~ "401|403" [$__auto]))'' "{{ vhost }}")
          ];
          min = 0;
        })
      ]

      {row = "Changes";}
      [
        (logs {
          title = "Authorized keys";
          w = 12;
          h = 8;
          targets = [(loki sshKeyChanges "")];
        })
        (logs {
          title = "Deploys";
          w = 12;
          h = 8;
          targets = [(loki ''{job="journal"} |= "finished switching to system configuration"'' "")];
        })
      ]
    ];
  }
