{
  pkgs,
  config,
  lib,
  namespace,
  ...
}: let
  inherit (builtins) toString toJSON;
  inherit (lib) mkEnableOption mkIf mkMerge mkOption optional optionals types;

  cfg = config.${namespace}.services.observability.alertmanager;

  port = 9040;
  botPort = 9041;

  domain = config.services.matrix-synapse.settings.server_name;
  botUser = "@alertmanager:${domain}";

  hasMatrix = cfg.matrix.room != null;

  credential = name: "/run/credentials/alertmanager.service/${name}";

  matrix = {
    url = "http://[::1]:${toString botPort}/alerts";
    send_resolved = true;
    # The bot takes its secret as the basic auth password
    http_config.basic_auth = {
      username = "alertmanager";
      password_file = credential "matrix";
    };
  };

  email = {
    to = cfg.email;
    from = "${config.networking.hostName} <chris@kruining.eu>";
    smarthost = "black-mail.nl:587";
    auth_username = "chris@kruining.eu";
    auth_password_file = credential "email";
    require_tls = true;
    send_resolved = true;
  };
in {
  options.${namespace}.services.observability.alertmanager = {
    enable = mkEnableOption "enable Alertmanager";

    email = mkOption {
      type = types.str;
      default = "chris@kruining.eu";
      description = ''
        Where critical alerts are mailed to, and every alert as long as there is no matrix room.
      '';
    };

    matrix.room = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "!abcdefghijklmnop:kruining.eu";
      description = ''
        Id of the (unencrypted) room the alerts are posted in. The bot joins it by itself once it has been invited.
      '';
    };

    deadMansSwitch = mkEnableOption ''
      pinging the url in the `alertmanager/dead_mans_switch` secret with the always firing Watchdog alert, an external
      service like healthchecks.io notices when the pings stop because this machine or its alerting is down
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.prometheus = {
        alertmanager = {
          enable = true;
          listenAddress = "[::1]";
          inherit port;

          configuration = {
            route = {
              receiver = "default";
              group_by = ["alertname" "job" "instance"];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";

              routes =
                optional cfg.deadMansSwitch {
                  matchers = [''alertname = "Watchdog"''];
                  receiver = "dead-mans-switch";
                  group_wait = "0s";
                  group_interval = "1m";
                  repeat_interval = "1m";
                }
                ++ [
                  # Without the dead man's switch the watchdog has nowhere to go
                  {
                    matchers = [''alertname = "Watchdog"''];
                    receiver = "void";
                  }
                  {
                    matchers = [''severity = "critical"''];
                    receiver = "critical";
                  }
                ];
            };

            # A critical alert makes the warning of the same thing redundant
            inhibit_rules = [
              {
                source_matchers = [''severity = "critical"''];
                target_matchers = [''severity = "warning"''];
                equal = ["alertname" "instance"];
              }
            ];

            receivers =
              [
                {name = "void";}
                (
                  if hasMatrix
                  then {
                    name = "default";
                    webhook_configs = [matrix];
                  }
                  else {
                    name = "default";
                    email_configs = [email];
                  }
                )
                {
                  name = "critical";
                  email_configs = [email];
                  webhook_configs = optional hasMatrix matrix;
                }
              ]
              ++ optional cfg.deadMansSwitch {
                name = "dead-mans-switch";
                webhook_configs = [
                  {
                    url_file = credential "dead_mans_switch";
                    send_resolved = false;
                  }
                ];
              };
          };
        };

        alertmanagers = [
          {
            static_configs = [
              {targets = ["[::1]:${toString port}"];}
            ];
          }
        ];

        rules = [
          (toJSON {
            groups = [
              {
                name = "meta";
                rules = [
                  {
                    alert = "Watchdog";
                    expr = "vector(1)";
                    labels.severity = "none";
                    annotations.summary = "Always firing, proves the whole alerting pipeline works";
                  }
                ];
              }
            ];
          })
        ];
      };

      ${namespace}.services.observability.loki.alertmanager = "http://[::1]:${toString port}";

      systemd.services.alertmanager.serviceConfig.LoadCredential =
        ["email:${config.sops.secrets."alertmanager/email".path}"]
        ++ optionals hasMatrix ["matrix:${config.sops.secrets."matrix_alertmanager/secret".path}"]
        ++ optionals cfg.deadMansSwitch ["dead_mans_switch:${config.sops.secrets."alertmanager/dead_mans_switch".path}"];

      sops.secrets =
        {
          "alertmanager/email".restartUnits = ["alertmanager.service"];
        }
        // lib.optionalAttrs cfg.deadMansSwitch {
          "alertmanager/dead_mans_switch".restartUnits = ["alertmanager.service"];
        };
    }

    (mkIf hasMatrix {
      services.matrix-alertmanager = {
        enable = true;
        port = botPort;
        homeserverUrl = "http://[::1]:${toString (lib.head config.services.matrix-synapse.settings.listeners).port}";
        matrixUser = botUser;
        matrixRooms = [
          {
            receivers = ["default" "critical"];
            roomId = cfg.matrix.room;
          }
        ];
        # The bot acts as the sender of its appservice, so the appservice token is its access token
        tokenFile = config.sops.secrets."matrix_alertmanager/as_token".path;
        secretFile = config.sops.secrets."matrix_alertmanager/secret".path;
      };

      systemd.services.matrix-alertmanager = {
        after = ["matrix-synapse.service"];

        # Synapse doesn't create the user of an appservice by itself
        preStart = ''
          response=$(${lib.getExe pkgs.curl} --silent --show-error \
            --header "Authorization: Bearer $(cat "$CREDENTIALS_DIRECTORY/token")" \
            --data '${toJSON {
            type = "m.login.application_service";
            username = "alertmanager";
          }}' \
            "${config.services.matrix-alertmanager.homeserverUrl}/_matrix/client/v3/register")

          case "$response" in
            *M_USER_IN_USE*|*user_id*) ;;
            *) echo "registering ${botUser} failed: $response"; exit 1 ;;
          esac
        '';
      };

      services.matrix-synapse.settings.app_service_config_files = [
        config.sops.templates."matrix_alertmanager/registration.yaml".path
      ];

      sops = {
        secrets = {
          "matrix_alertmanager/as_token".restartUnits = ["matrix-alertmanager.service"];
          "matrix_alertmanager/hs_token" = {};
          "matrix_alertmanager/secret".restartUnits = ["matrix-alertmanager.service" "alertmanager.service"];
        };

        templates."matrix_alertmanager/registration.yaml" = {
          owner = "matrix-synapse";
          restartUnits = ["matrix-synapse.service"];
          # Only used to authenticate the bot, so synapse has nothing to push to
          content = toJSON {
            id = "alertmanager";
            url = null;
            as_token = config.sops.placeholder."matrix_alertmanager/as_token";
            hs_token = config.sops.placeholder."matrix_alertmanager/hs_token";
            sender_localpart = "alertmanager";
            rate_limited = false;
            namespaces = {
              users = [
                {
                  exclusive = true;
                  regex = lib.escapeRegex botUser;
                }
              ];
              aliases = [];
              rooms = [];
            };
          };
        };
      };
    })
  ]);
}
