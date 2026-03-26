{lib, ...}: let
  inherit (builtins) isString typeOf match toString head;
  inherit (lib) throwIfNot concatStringsSep splitStringBy toLower map concatMapAttrsStringSep;
in {
  strings = {
    #========================================================================================
    # Converts a string to snake case
    #
    # simply replaces any uppercase letter to its lowercase variant preceeded by an underscore
    #========================================================================================
    toSnakeCase = str:
      throwIfNot (isString str) "toSnakeCase only accepts string values, but got ${typeOf str}" (
        str
        |> splitStringBy (prev: curr: builtins.match "[a-z]" prev != null && builtins.match "[A-Z]" curr != null) true
        |> map (p: toLower p)
        |> concatStringsSep "_"
      );

    #========================================================================================
    # Converts a set of url parts to a string
    #========================================================================================
    toUrl = {
      protocol ? null,
      host,
      port ? null,
      path ? null,
      query ? null,
      hash ? null,
    }: let
      trim_slashes = str: str |> match "^\/*(.+?)\/*$" |> head;
      encode_to_str = set: concatMapAttrsStringSep "&" (n: v: "${n}=${v}") set;

      _protocol =
        if protocol != null
        then "${protocol}://"
        else "";
      _port =
        if port != null
        then ":${toString port}"
        else "";
      _path =
        if path != null
        then "/${path |> trim_slashes}"
        else "";
      _query =
        if query != null
        then "?${query |> encode_to_str}"
        else "";
      _hash =
        if hash != null
        then "#${hash |> encode_to_str}"
        else "";
    in "${_protocol}${host}${_port}${_path}${_query}${_hash}";
  };
}
