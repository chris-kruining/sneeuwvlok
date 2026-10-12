{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types genAttrs mapAttrs' nameValuePair filterAttrs hasSuffix removeSuffix concatStringsSep;

  cfg = config.${namespace}.services.home-automation.home-assistant;
  # The user the nixpkgs module runs home assistant as, the database is named after it so it can log in through the socket
  user = "hass";
  configDir = config.services.home-assistant.configDir;

  domain = "home.kruining.eu";
  # Home assistant is only reachable from home, either on the LAN or through the VPN. The LAN has public IPv6 addresses
  # from this prefix, so private ranges alone would lock out every device at home that prefers IPv6.
  allowedNetworks = ["private_ranges" "2a0d:6e00:1dc9::/48"];

  # Every `<domain>.yaml` in ./config is included as the configuration of that domain, so `switch.yaml` becomes `switch: !include ...`
  declarative =
    builtins.readDir ./config
    |> filterAttrs (name: type: type == "regular" && hasSuffix ".yaml" name)
    |> mapAttrs' (name: _: nameValuePair (removeSuffix ".yaml" name) "!include ${./config + "/${name}"}");
in {
  options.${namespace}.services.home-automation.home-assistant = {
    enable = mkEnableOption "Home Assistant";

    # Since 2026.9 home assistant keeps its http settings in its own storage (`.storage/http`), so nix
    # can't own the port. `SETUP_PORT` only sets the port that storage starts with on the first start,
    # changing this afterwards does nothing until that storage is removed.
    port = mkOption {
      type = types.port;
      default = 6010;
      readOnly = true;
      description = ''
        The port home assistant listens on
      '';
    };
  };

  config = mkIf cfg.enable {
    ${namespace}.services = {
      persistance.postgresql.enable = true;
      home-automation.piper.enable = true;

      # The public name lets caddy get a certificate, so the companion app gets the https it demands. Everyone
      # outside the allowed networks has the connection dropped before anything is proxied.
      networking.caddy.hosts.${domain} = ''
        @outside not remote_ip ${concatStringsSep " " allowedNetworks}
        abort @outside

        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };

    networking.firewall.allowedTCPPorts = [cfg.port];

    # The `hass` cli, from the same package the service runs
    environment.systemPackages = [config.services.home-assistant.package];

    services = {
      home-assistant = {
        enable = true;

        # psycopg2 lets the recorder store its history in postgres instead of sqlite
        extraPackages = ps: with ps; [psycopg2];
        extraComponents = [
          "default_config"
          # Onboarding sets up the weather forecast with it
          "met"
          # Zigbee through the usb antenna, the nixpkgs module gives the service access to serial devices for it
          "zha"
          # Text to speech through the local piper server
          "wyoming"
          # The unifi network, its clients double as presence detection. Discovery finds the console on the LAN
          "unifi"
          "unifi_discovery"
        ];

        config = {
          default_config = {};

          recorder.db_url = "postgresql://@/${user}";

          # Automations, scenes and scripts made in the UI are kept in these files, the rest of
          # the configuration is owned by nix.
          "automation ui" = "!include automations.yaml";
          "scene ui" = "!include scenes.yaml";
          "script ui" = "!include scripts.yaml";

          # Taking the `lovelace` url replaces the generated overview, so the home page only shows what is in this file
          lovelace.dashboards.lovelace = {
            mode = "yaml";
            filename = "${./dashboards/home.yaml}";
            title = "Thuis";
            icon = "mdi:home";
            show_in_sidebar = true;
            require_admin = false;
          };
        }
        // declarative;
      };

      postgresql = {
        ensureDatabases = [user];
        ensureUsers = [
          {
            name = user;
            ensureDBOwnership = true;
          }
        ];
      };
    };

    systemd = {
      services.home-assistant = {
        environment.SETUP_PORT = toString cfg.port;

        # The recorder only connects once at startup
        requires = ["postgresql.target"];
        after = ["postgresql.target"];
      };

      # Home assistant refuses to start when an included file is missing
      tmpfiles.settings.home-assistant = genAttrs (map (name: "${configDir}/${name}.yaml") ["automations" "scenes" "scripts"]) (_: {
        f = {
          inherit user;
          group = user;
          mode = "0644";
        };
      });
    };
  };
}
