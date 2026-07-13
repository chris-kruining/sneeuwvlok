{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    metrics = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          jobName = mkOption {
            type = types.str;
            default = name;
          };

          targets = mkOption {
            type = types.listOf (types.submoduleWith {
              modules = [../types/endpoint.nix];
            });
            default = [];
          };

          labels = mkOption {
            type = types.attrsOf types.str;
            default = {};
          };
        };
      }));
      default = {};
    };

    logs = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          unit = mkOption {
            type = types.nullOr types.str;
            default = name;
          };

          labels = mkOption {
            type = types.attrsOf types.str;
            default = {};
          };
        };
      }));
      default = {};
    };

    traces = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          serviceName = mkOption {
            type = types.str;
            default = name;
          };

          protocol = mkOption {
            type = types.enum ["otlp-grpc" "otlp-http"];
            default = "otlp-grpc";
          };
        };
      }));
      default = {};
    };
  };
}
