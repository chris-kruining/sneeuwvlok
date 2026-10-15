# Helpers to write grafana dashboards in nix. Panels are laid out by `dashboard`: it takes a list of rows, where a row
# is either a list of panels next to each other, or `{ row = "title"; }` for a header. Every panel has a width `w` (of
# 24) and a height `h`.
{lib, ...}: let
  inherit (builtins) elemAt head removeAttrs substring;
  inherit (lib) foldl imap0 imap1 max recursiveUpdate;

  letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

  datasources = {
    prometheus = {
      type = "prometheus";
      uid = "prometheus";
    };
    loki = {
      type = "loki";
      uid = "loki";
    };
    alertmanager = {
      type = "alertmanager";
      uid = "alertmanager";
    };
  };

  # Every target gets a refId, the panel takes the data source of its first target
  panel = type: defaults: {
    title,
    targets ? [],
    w ? 6,
    h ? 8,
    unit ? null,
    description ? null,
    thresholds ? null,
    min ? null,
    max ? null,
    decimals ? null,
    overrides ? [],
    transformations ? [],
    extra ? {},
  }: let
    withIds = imap0 (index: target: {refId = substring index 1 letters;} // target) targets;
  in
    recursiveUpdate
    (defaults
      // {
        inherit type title w h transformations;
        targets = withIds;
        fieldConfig = recursiveUpdate (defaults.fieldConfig or {}) {
          defaults =
            lib.filterAttrs (_: value: value != null) {inherit unit min max decimals thresholds;};
          inherit overrides;
        };
      }
      // lib.optionalAttrs (description != null) {inherit description;}
      // lib.optionalAttrs (withIds != []) {datasource = (head withIds).datasource;})
    extra;
in {
  grafana = rec {
    inherit datasources;

    # Queries, `legend` names the series by their labels like "{{ host }}"
    prometheus = expr: legend: {
      datasource = datasources.prometheus;
      inherit expr;
      legendFormat = legend;
      range = true;
    };

    # An instant query, for tables and stats of the current value
    prometheusNow = expr: legend: {
      datasource = datasources.prometheus;
      inherit expr;
      legendFormat = legend;
      instant = true;
      range = false;
      format = "table";
    };

    # The value at the end of the time range, for stats over `$__range`
    prometheusTotal = expr: {
      datasource = datasources.prometheus;
      inherit expr;
      legendFormat = "";
      instant = true;
      range = false;
    };

    loki = expr: legend: {
      datasource = datasources.loki;
      inherit expr;
      legendFormat = legend;
      queryType = "range";
    };

    # Over the whole time range, for top lists and totals
    lokiTotal = expr: legend: {
      datasource = datasources.loki;
      inherit expr;
      legendFormat = legend;
      queryType = "instant";
    };

    # `steps` are [ value color ] pairs on top of the base color
    thresholds = base: steps: {
      mode = "absolute";
      steps =
        [
          {
            color = base;
            value = null;
          }
        ]
        ++ map (step: {
          value = elemAt step 0;
          color = elemAt step 1;
        })
        steps;
    };

    stat = panel "stat" {
      options = {
        reduceOptions = {
          calcs = ["lastNotNull"];
          fields = "";
          values = false;
        };
        colorMode = "value";
        graphMode = "none";
        textMode = "auto";
        justifyMode = "auto";
        orientation = "auto";
      };
    };

    timeseries = panel "timeseries" {
      fieldConfig.defaults.custom = {
        drawStyle = "line";
        lineWidth = 1;
        fillOpacity = 10;
        showPoints = "never";
        spanNulls = false;
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
    };

    # Series on top of each other, for parts of a whole
    stacked = args:
      timeseries (recursiveUpdate args {
        extra.fieldConfig.defaults.custom.stacking = {
          mode = "normal";
          group = "A";
        };
      });

    bars = args:
      timeseries (recursiveUpdate args {
        extra.fieldConfig.defaults.custom = {
          drawStyle = "bars";
          fillOpacity = 80;
          stacking = {
            mode = "normal";
            group = "A";
          };
        };
      });

    bargauge = panel "bargauge" {
      options = {
        displayMode = "gradient";
        orientation = "horizontal";
        showUnfilled = true;
        valueMode = "color";
        namePlacement = "auto";
        reduceOptions = {
          calcs = ["lastNotNull"];
          fields = "";
          values = false;
        };
      };
    };

    table = panel "table" {
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
      };
    };

    logs = panel "logs" {
      options = {
        showTime = true;
        wrapLogMessage = true;
        sortOrder = "Descending";
        enableLogDetails = true;
        dedupStrategy = "none";
        prettifyLogMessage = false;
      };
    };

    # The alerts of prometheus' and loki's rulers, through the data sources that manage them
    alertlist = args:
      panel "alertlist" {
        options = {
          viewMode = "list";
          groupMode = "default";
          groupBy = [];
          maxItems = 20;
          sortOrder = 1;
          dashboardAlerts = false;
          alertName = "";
          alertInstanceLabelFilter = "{severity!=\"none\"}";
          datasource = "";
          stateFilter = {
            firing = true;
            pending = true;
            noData = false;
            normal = false;
            error = true;
          };
        };
      }
      args;

    # A table of one value per series, named by its legend, largest first
    top = key: value: args:
      table (recursiveUpdate args {
        transformations = [
          {
            id = "reduce";
            options = {
              reducers = ["lastNotNull"];
              mode = "seriesToRows";
            };
          }
          {
            id = "organize";
            options.renameByName = {
              Field = key;
              "Last *" = value;
            };
          }
        ];
        extra.options.sortBy = [
          {
            displayName = value;
            desc = true;
          }
        ];
      });

    # Leaves columns of a table out
    hide = columns: [
      {
        id = "organize";
        options.excludeByName = lib.genAttrs columns (_: true);
      }
    ];

    # Merges the instant queries of a table into one row per series, `columns` renames them by refId
    mergeColumns = columns: [
      {
        id = "merge";
        options = {};
      }
      {
        id = "organize";
        options = {
          excludeByName = {
            Time = true;
            job = true;
            __name__ = true;
          };
          # A single letter is the refId of a query, anything else a label
          renameByName =
            lib.mapAttrs' (column: name:
              lib.nameValuePair (
                if builtins.stringLength column == 1
                then "Value #${column}"
                else column
              )
              name)
            columns;
        };
      }
    ];

    # Changes the field of the given name, like `{ unit = "s"; }`
    override = name: properties: {
      matcher = {
        id = "byName";
        options = name;
      };
      properties = lib.mapAttrsToList (id: value: {inherit id value;}) properties;
    };

    color = name: color:
      override name {
        color = {
          mode = "fixed";
          fixedColor = color;
        };
      };

    # Marks in every time series, from loki
    annotation = name: color: expr: {
      inherit name expr;
      datasource = datasources.loki;
      enable = true;
      iconColor = color;
      target = {
        inherit expr;
        queryType = "range";
        refId = "Anno";
      };
    };

    # Every activation of a new system configuration
    deploys = annotation "Deploys" "blue" ''{job="journal"} |= "finished switching to system configuration"'';

    # A variable of label values
    variable = name: label: query: {
      inherit name label query;
      type = "query";
      datasource = datasources.prometheus;
      definition = query;
      refresh = 2;
      multi = true;
      includeAll = true;
      allValue = ".*";
      current = {
        text = "All";
        value = "$__all";
      };
    };

    dashboard = {
      uid,
      title,
      rows,
      tags ? [],
      time ? "now-24h",
      variables ? [],
      annotations ? [],
    }: let
      placeLine = y: panels:
        (foldl (line: panel: {
            x = line.x + panel.w;
            panels =
              line.panels
              ++ [
                (removeAttrs panel ["w" "h"]
                  // {
                    gridPos = {
                      inherit (panel) w h;
                      inherit (line) x;
                      inherit y;
                    };
                  })
              ];
          }) {
            x = 0;
            panels = [];
          }
          panels)
        .panels;

      place = state: row:
        if row ? row
        then {
          y = state.y + 1;
          panels =
            state.panels
            ++ [
              {
                type = "row";
                title = row.row;
                collapsed = false;
                panels = [];
                gridPos = {
                  x = 0;
                  inherit (state) y;
                  w = 24;
                  h = 1;
                };
              }
            ];
        }
        else {
          y = state.y + foldl max 0 (map (panel: panel.h) row);
          panels = state.panels ++ placeLine state.y row;
        };

      placed = foldl place {
        y = 0;
        panels = [];
      }
      rows;
    in {
      inherit uid title tags;
      editable = false;
      timezone = "browser";
      refresh = "1m";
      schemaVersion = 39;
      time = {
        from = time;
        to = "now";
      };
      panels = imap1 (id: panel: panel // {inherit id;}) placed.panels;
      templating.list = variables;
      annotations.list =
        [
          {
            builtIn = 1;
            datasource = {
              type = "grafana";
              uid = "-- Grafana --";
            };
            enable = true;
            hide = true;
            iconColor = "rgba(0, 211, 255, 1)";
            name = "Annotations & Alerts";
            type = "dashboard";
          }
        ]
        ++ annotations;
    };
  };
}
