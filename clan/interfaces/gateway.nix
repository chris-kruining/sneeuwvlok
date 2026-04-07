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
            default = name;
          };

          # protocol = mkOption {
          #   type = types.str;
          #   default = "http";
          # };

          # host = mkOption {
          #   type = types.str;
          #   default = "[::1]";
          # };

          # port = mkOption {
          #   type = types.port;
          # };
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
