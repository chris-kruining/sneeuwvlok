{ lib, ...}:
let
  inherit (builtins) isString typeOf;
  inherit (lib) throwIfNot concatStringsSep splitStringBy toLower map;
in
{
  strings = {
    toSnakeCase = 
      str:
      throwIfNot (isString str) "toSnakeCase only accepts string values, but got ${typeOf str}" (
        str
          |> splitStringBy (prev: curr: builtins.match "[a-z]" prev != null && builtins.match "[A-Z]" curr != null) true
          |> map (p: toLower p)
          |> concatStringsSep "_"
      );
  };
}