{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.signal;
in
{
  options.${namespace}.application.signal = {
    enable = mkEnableOption "enable signal";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ signal-desktop ];
  };
}
