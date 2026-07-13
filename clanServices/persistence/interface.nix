{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    driver = mkOption {
      type = types.enum ["postgresql"];
      default = "postgresql";
    };

    postgresql = mkOption {
      type = types.submodule {
        options = {
          host = mkOption {
            type = types.str;
            default = "localhost";
          };

          port = mkOption {
            type = types.port;
            default = 5432;
          };
        };
      };
      default = {};
    };

  };
}
