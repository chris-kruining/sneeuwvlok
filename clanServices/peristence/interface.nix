{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    port = mkOption {
      type = types.port;
      default = 5432;
    };
  };
}
