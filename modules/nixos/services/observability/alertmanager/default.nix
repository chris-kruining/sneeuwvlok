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
  roomAlias = "#alertmanager:${domain}";
  homeserver = "http://[::1]:${toString (lib.head config.services.matrix-synapse.settings.listeners).port}";

  hasMatrix = cfg.matrix.enable;

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
        Where critical alerts are mailed to, and every alert when they don't go to matrix.
      '';
    };

    matrix = {
      enable = mkEnableOption ''
        posting alerts in a matrix room, which the bot creates itself and invites the users of `invite` to
      '';

      invite = mkOption {
        type = types.listOf types.str;
        default = ["@chris:${domain}"];
        defaultText = "[ \"@chris:<server name>\" ]";
        description = ''
          Users invited to the alert room when the bot creates it, they become its admins.
        '';
      };
    };

    deadMansSwitch = mkEnableOption ''
      pinging the url in the `alertmanager/dead_mans_switch` secret every minute with the always firing Watchdog alert,
      so a service somewhere else notices when the pings stop because this machine or its alerting is down
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
          "alertmanager/email" = {
            key = "email/chris_kruining_eu";
            restartUnits = ["alertmanager.service"];
          };
        }
        // lib.optionalAttrs cfg.deadMansSwitch {
          "alertmanager/dead_mans_switch".restartUnits = ["alertmanager.service"];
        };
    }

    (mkIf hasMatrix {
      # Bridges create their own rooms as well, the bot is the sender of an appservice so its token is the as_token
      systemd.services.matrix-alertmanager = {
        description = "Post the alerts of Alertmanager in a matrix room";
        after = ["network.target" "matrix-synapse.service"];
        wants = ["matrix-synapse.service"];
        wantedBy = ["multi-user.target"];

        path = [pkgs.curl pkgs.jq];

        environment = {
          APP_PORT = toString botPort;
          MATRIX_HOMESERVER_URL = homeserver;
          MATRIX_USER = botUser;
          MENTION_ROOM = "0";
          NODE_ENV = "production";
        };

        script = ''
          token=$(cat "$CREDENTIALS_DIRECTORY/token")

          matrix() {
            curl --silent --show-error --header "Authorization: Bearer $token" "$@"
          }

          # Synapse doesn't create the user of an appservice by itself
          response=$(matrix --data '${toJSON {
            type = "m.login.application_service";
            username = "alertmanager";
          }}' "${homeserver}/_matrix/client/v3/register")

          case "$response" in
            *M_USER_IN_USE*|*user_id*) ;;
            *) echo "registering ${botUser} failed: $response"; exit 1 ;;
          esac

          room=$(matrix "${homeserver}/_matrix/client/v3/directory/room/${lib.escapeURL roomAlias}" | jq -r '.room_id // empty')

          if [ -z "$room" ]; then
            room=$(matrix --data '${toJSON {
            room_alias_name = "alertmanager";
            name = "Alerts";
            topic = "Alerts of ${config.networking.hostName}";
            preset = "private_chat";
            inherit (cfg.matrix) invite;
            power_level_content_override.users =
              lib.genAttrs cfg.matrix.invite (_: 100) // {${botUser} = 100;};
          }}' "${homeserver}/_matrix/client/v3/createRoom" | jq -r '.room_id // empty')
          fi

          if [ -z "$room" ]; then
            echo "could not find or create ${roomAlias}"
            exit 1
          fi

          secret=$(cat "$CREDENTIALS_DIRECTORY/secret")

          export MATRIX_ROOMS="default/critical/$room"
          export MATRIX_TOKEN="$token"
          export APP_ALERTMANAGER_SECRET="$secret"

          exec ${lib.getExe pkgs.matrix-alertmanager}
        '';

        serviceConfig = {
          DynamicUser = true;
          Restart = "always";
          RestartSec = "10s";
          LoadCredential = [
            "token:${config.sops.secrets."matrix_alertmanager/as_token".path}"
            "secret:${config.sops.secrets."matrix_alertmanager/secret".path}"
          ];
        };
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
              aliases = [
                {
                  exclusive = true;
                  regex = lib.escapeRegex roomAlias;
                }
              ];
              rooms = [];
            };
          };
        };
      };
    })
  ]);
}
