{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    protocol = mkOption {
      type = types.str;
      default = "http";
    };

    host = mkOption {
      type = types.str;
      default = "localhost";
    };

    port = mkOption {
      type = types.nullOr types.port;
      default = null;
    };

    user = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    password = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    path = mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    query = mkOption {
      type = types.nullOr (types.attrsOf types.str);
      default = null;
    };

    hash = mkOption {
      type = types.nullOr (types.attrsOf types.str);
      default = null;
    };
  };
}
