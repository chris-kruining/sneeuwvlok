{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
in {
  imports = [
    ./options
    ./strings
  ];

  config = {
    _module.args = {
      inherit
        baseNixosModules
        channelConfig
        mkPkgs
        sharedContext
        systemOverlays
        ;
    };

    flake.lib = config.localLib;
  };
}
