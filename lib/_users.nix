args@{ lib, pkgs, ... }: let
  inherit (lib.my.modules) mapModulesRec';
in
{
    imports = []
    ++ (mapModulesRec' (toString ../modules) (file: import file (args // { user = "chris"; })))
    ++ (mapModulesRec' (toString ../modules) (file: import file (args // { user = "kaas"; })));

    config = {};
}