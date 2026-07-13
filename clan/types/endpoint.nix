{lib, ...}: let
  inherit (lib) concatMapAttrsStringSep mkOption types;

  trimSlashes = str: str |> builtins.match "^/*(.+?)/*$" |> builtins.head;
  encodeAttrs = attrs: concatMapAttrsStringSep "&" (name: value: "${name}=${value}") attrs;
  endpointToString = endpoint: let
    protocol =
      if endpoint.protocol != null
      then "${endpoint.protocol}://"
      else "";
    port =
      if endpoint.port != null
      then ":${toString endpoint.port}"
      else "";
    path =
      if endpoint.path != null
      then "/${trimSlashes endpoint.path}"
      else "";
    query =
      if endpoint.query != null
      then "?${encodeAttrs endpoint.query}"
      else "";
    hash =
      if endpoint.hash != null
      then "#${encodeAttrs endpoint.hash}"
      else "";
  in "${protocol}${endpoint.host}${port}${path}${query}${hash}";
in {
  options = {
    __toString = mkOption {
      type = types.functionTo types.str;
      default = endpointToString;
      visible = false;
      readOnly = true;
    };

    protocol = mkOption {
      type = types.nullOr types.str;
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
