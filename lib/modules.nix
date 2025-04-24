{ lib, self, ... }:
let
  inherit (builtins) attrValues readDir pathExists concatLists replaceStrings listToAttrs;
  inherit (lib.attrsets) mapAttrsToList filterAttrs nameValuePair;
  inherit (lib.strings) hasPrefix hasSuffix removeSuffix removePrefix;
  inherit (lib.trivial) id;
  inherit (lib) flatten;
  inherit (self.attrs) mapFilterAttrs;
in rec
{
  mapModules = dir: fn:
    mapFilterAttrs (n: v: v != null && !(hasPrefix "_" n)) (n: v: let path = "${toString dir}/${n}"; in
      if v == "directory" && pathExists "${path}/default.nix"
        then nameValuePair n (fn path)
      else if v == "regular" && n != "default.nix" && hasSuffix ".nix" n && !(hasPrefix "_" n)
        then nameValuePair (removeSuffix ".nix" n) (fn path)
      else nameValuePair "" null
    ) (readDir dir);

  mapModules' = dir: fn: attrValues (mapModules dir fn);

  mapModulesRec = dir: fn:
    mapFilterAttrs (n: v: v != null && !(hasPrefix "_" n)) (n: v: let path = "${toString dir}/${n}"; in
      if v == "directory" && pathExists "${path}/default.nix"
        then nameValuePair n (mapModulesRec path fn)
      else if v == "regular" && n != "default.nix" && hasSuffix ".nix" n
        then nameValuePair (removeSuffix ".nix" n) (fn path)
      else nameValuePair "" null
    ) (readDir dir);

  mapModulesRec' = dir: fn: let
    dirs = mapAttrsToList (k: _: "${dir}/${k}") (filterAttrs (n: v: v == "directory" && !(hasPrefix "_" n)) (readDir dir));
    files = attrValues (mapModules dir id);
    paths = files ++ concatLists (map (d: mapModulesRec' d id) dirs);
  in
    map fn paths;

  readNixosModules = dir: fn: filterAttrs (name: value: value != null && !(hasPrefix "_" name)) (listToAttrs (flatten (readDirRecursive fn dir "")));

  readDirRecursive = fn: root: dir: mapAttrsToList (name: type:
    if type == "directory" && pathExists "${root}/${dir}/${name}/default.nix"
      then [
        (nameValuePair "${replaceStrings ["/"] ["_"] (removePrefix "/" dir)}_${name}" (fn "${root}/${dir}/${name}/default.nix"))
        (readDirRecursive fn root "${dir}/${name}")
      ]
    else if type == "directory"
      then readDirRecursive fn root "${dir}/${name}"
    else if type == "regular" && name != "default.nix" && hasSuffix ".nix" name
      then nameValuePair "${replaceStrings ["/"] ["_"] (removePrefix "/" dir)}_${removeSuffix ".nix" name}" (fn "${root}/${dir}/${name}")
    else nameValuePair "" null
  ) (readDir "${root}/${dir}");
}
