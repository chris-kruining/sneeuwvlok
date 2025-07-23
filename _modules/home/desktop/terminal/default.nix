{ config, options, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkDefault mkIf mkMerge;

  cfg = config.modules.${user}.desktop.terminal;
in {
  options.modules.${user}.desktop.terminal = let
    inherit (lib.options) mkOption;
    inherit (lib.types) str;
  in {
    default = mkOption {
      type = str;
      default = "alacrity";
      description = "Default terminal";
      example = "alacrity";
    };
  };

  config = mkMerge [
    {
      home-manager.users.${user}.home.sessionVariables.TERMINAL = cfg.default;
    }
  ];
}
