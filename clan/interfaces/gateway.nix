{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    services = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
          };

          endpoint = mkOption {
            type = types.submoduleWith {
              modules = [../types/endpoint.nix];
            };
            default = {};
          };

          routes = mkOption {
            type = types.attrsOf (types.submodule ({name, ...}: {
              options = {
                host = mkOption {
                  type = types.str;
                  default = name;
                };

                functions = mkOption {
                  type = types.listOf types.str;
                  default = [];
                };
              };
            }));
            default = {};
          };
        };
      }));
      default = {};
    };

    routes = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          host = mkOption {
            type = types.str;
            default = name;
          };

          endpoint = mkOption {
            type = types.submoduleWith {
              modules = [../types/endpoint.nix];
            };
            default = {};
          };

          functions = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          extraConfig = mkOption {
            type = types.lines;
            default = "";
          };
        };
      }));
      default = {};
    };

    functions = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
          };

          body = mkOption {
            type = types.str;
          };
        };
      }));
      default = {};
    };
  };
}
