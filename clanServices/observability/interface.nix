{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [
    ../../clan/interfaces/observability.nix
  ];

  options = {
    driver = mkOption {
      type = types.enum ["grafana"];
      default = "grafana";
    };

    grafana = mkOption {
      type = types.submodule {
        options = {
          grafana.enable = mkEnableOption "Grafana";
          prometheus.enable = mkEnableOption "Prometheus";
          loki.enable = mkEnableOption "Loki";
          tempo.enable = mkEnableOption "Tempo";
          alloy.enable = mkEnableOption "Alloy";

          ports = mkOption {
            type = types.submodule {
              options = {
                grafana = mkOption {
                  type = types.port;
                  default = 9001;
                };
                prometheus = mkOption {
                  type = types.port;
                  default = 9002;
                };
                loki = mkOption {
                  type = types.port;
                  default = 9003;
                };
                tempoOtlpGrpc = mkOption {
                  type = types.port;
                  default = 9062;
                };
                tempoOtlpHttp = mkOption {
                  type = types.port;
                  default = 9063;
                };
                alloyOtlpGrpc = mkOption {
                  type = types.port;
                  default = 9071;
                };
                alloyOtlpHttp = mkOption {
                  type = types.port;
                  default = 9072;
                };
              };
            };
            default = {};
          };

          host = mkOption {
            type = types.nullOr types.str;
            default = null;
          };

          oidcCallbackPath = mkOption {
            type = types.str;
            default = "/login/generic_oauth";
          };
        };
      };
      default = {};
    };

    identity = mkOption {
      type = types.submoduleWith {
        modules = [../../clan/interfaces/identity.nix];
      };
      default = {};
    };
  };
}
