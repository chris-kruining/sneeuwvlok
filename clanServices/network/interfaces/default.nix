{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    range = mkOption {
      type = types.submodule {
        options = {
          start = mkOption {
            type = types.port;
            default = 20000;
          };

          end = mkOption {
            type = types.port;
            default = 49999;
          };
        };
      };
      default = {};
    };
  };
}
