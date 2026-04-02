{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    main = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    driver = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };

    databases = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };
}
