{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkPackageOption mkIf mkOption optionalAttrs recursiveUpdate types baseNameOf;

  cfg = config.services.arrtrix;
  dataDir = "/var/lib/arrtrix";
  registrationFile = "${dataDir}/arrtrix-registration.yaml";
  settingsFile = "${dataDir}/config.yaml";
  settingsFileUnsubstituted = settingsFormat.generate "arrtrix-config-unsubstituted.json" cfg.settings;
  settingsFormat = pkgs.formats.json {};

  defaultConfig = {
    bridge = {
      command_prefix = "!arr";
      relay.enabled = true;
      permissions."*" = "relay";
    };
    database = {
      type = "sqlite3-fk-wal";
      uri = "file:${dataDir}/arrtrix.db?_txlock=immediate";
    };
    homeserver = {
      address = "http://localhost:8448";
      domain = config.services.matrix-synapse.settings.server_name or "example.com";
    };
    appservice = {
      hostname = "[::]";
      port = 29329;
      id = "arrtrix";
      bot = {
        username = "arrtrixbot";
        displayname = "arrtrix Bot";
      };
      as_token = "";
      hs_token = "";
      username_template = "arrtrix_{{.}}";
    };
    logging = {
      min_level = "info";
      writers = lib.singleton {
        type = "stdout";
        format = "pretty-colored";
        time_format = " ";
      };
    };
    observability = {
      otlp_grpc_endpoint = "";
      service_name = "arrtrix";
      resource_attributes = {};
    };
    network.content = {
      movies = {
        url = "";
        api_key = "";
        root_folder_path = "";
        quality_profile_id = 0;
        minimum_availability = "released";
        search_on_add = true;
      };
      series = {
        url = "";
        api_key = "";
        root_folder_path = "";
        quality_profile_id = 0;
        language_profile_id = 0;
        season_folder = true;
        series_type = "standard";
        search_on_add = true;
      };
    };
  };
in {
  options.services.arrtrix = {
    enable = mkEnableOption "Arr-focused Matrix appservice foundation";

    package = mkPackageOption pkgs.${namespace} "arrtrix" {};

    registerToSynapse = mkOption {
      type = types.bool;
      default = config.services.matrix-synapse.enable;
      defaultText = lib.literalExpression ''
        config.services.matrix-synapse.enable
      '';
      description = ''
        Whether to add the bridge's app service registration file to
        `services.matrix-synapse.settings.app_service_config_files`.
      '';
    };

    settings = mkOption {
      apply = lib.recursiveUpdate defaultConfig;
      type = settingsFormat.type;
      default = defaultConfig;
      description = ''
        {file}`config.yaml` configuration as a Nix attribute set.
        Configuration options should match those described in the example configuration.
        Get an example configuration by executing `arrtrix -c example.yaml --generate-example-config`
        Secret tokens should be specified using {option}`environmentFile`
        instead of this world-readable attribute set.
      '';
      example = {};
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing environment variables to be passed to the arrtrix service.
        If an environment variable `ARRTRIX_BRIDGE_LOGIN_SHARED_SECRET` is set,
        then its value will be used in the configuration file for the option
        `double_puppet.secrets` without leaking it to the store, using the configured
        `homeserver.domain` as key.
      '';
    };

    serviceDependencies = lib.mkOption {
      type = with lib.types; listOf str;
      default =
        (lib.optional config.services.matrix-synapse.enable config.services.matrix-synapse.serviceUnit)
        ++ (lib.optional config.services.matrix-conduit.enable "conduit.service");
      defaultText = lib.literalExpression ''
        (optional config.services.matrix-synapse.enable config.services.matrix-synapse.serviceUnit)
        ++ (optional config.services.matrix-conduit.enable "conduit.service")
      '';
      description = ''
        List of systemd units to require and wait for when starting the application service.
      '';
    };
  };

  config = mkIf cfg.enable {
    users = {
      users."arrtrix" = {
        isSystemUser = true;
        group = "arrtrix";
      };
      groups."arrtrix" = {};
    };

    services.matrix-synapse = lib.mkIf cfg.registerToSynapse {
      settings.app_service_config_files = [registrationFile];
    };
    systemd.services.matrix-synapse = lib.mkIf cfg.registerToSynapse {
      serviceConfig.SupplementaryGroups = ["arrtrix"];
    };

    systemd.services.arrtrix = {
      description = "arrtrix, A *arr stack to matrix bridge for *arr-notifications";

      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [settingsFileUnsubstituted];

      preStart = ''
        # substitute the settings file by environment variables
        # in this case read from EnvironmentFile
        test -f '${settingsFile}' && rm -f '${settingsFile}'

        old_umask=$(umask)
        umask 0177
        ${lib.getExe pkgs.envsubst} -o '${settingsFile}' -i '${settingsFileUnsubstituted}'
        umask $old_umask

        if [ ! -f '${registrationFile}' ]; then
            ${lib.getExe cfg.package} --generate-registration --config='${settingsFile}' --registration='${registrationFile}'
        fi
        chmod 640 ${registrationFile}
      '';

      serviceConfig = {
        Type = "simple";
        User = "arrtrix";
        Group = "arrtrix";

        StateDirectory = baseNameOf dataDir;
        WorkingDirectory = dataDir;
        EnvironmentFile = cfg.environmentFile;

        ExecStart = ''
          ${lib.getExe cfg.package} --config='${settingsFile}' --registration='${registrationFile}'
        '';

        Restart = "on-failure";
        RestartSec = "30s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;

        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = ["@system-service"];
        UMask = "0027";
      };
    };
  };
}
