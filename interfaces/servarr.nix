{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    services = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          port = mkOption {
            type = types.port;
          };
        };
      });
      default = {};
    };
  };
}
