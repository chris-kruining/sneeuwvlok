{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.thunderbird;
in
{
  options.${namespace}.application.thunderbird = {
    enable = mkEnableOption "enable thunderbird";
  };

  config = mkIf cfg.enable {
    programs.thunderbird = {
      enable = true;
    };
  };
}
