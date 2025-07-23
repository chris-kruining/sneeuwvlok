{ lib, ... }:
let
  inherit (lib.lists) any count;
  inherit (lib.attrsets) filterAttrs listToAttrs mapAttrs' mapAttrsToList;
in rec
{
  attrsToList = attrs: 
    mapAttrsToList (name: value: { inherit name value; }) attrs;

  mapFilterAttrs = pred: f: attrs: 
    filterAttrs pred (mapAttrs' f attrs);

  getAttrs' = values: f: 
    listToAttrs (map f values);

  anyAttrs = pred: attrs: 
    any (attr: pred attr.name attr.value) (attrsToList attrs);

  countAttrs = pred: attrs:
    count (attr: pred attr.name attr.value) (attrsToList attrs);
}
