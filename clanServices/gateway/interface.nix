{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    driver = mkOption {
      type = types.enum ["caddy" "nginx"];
    };

    hosts = mkOption {
      type = types.attrsOf types.str;
      default = {};
    };
  };
}
