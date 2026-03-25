{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.signal;
in
{
  options.sneeuwvlok.application.signal = {
    enable = mkEnableOption "enable signal";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ signal-desktop ];
  };
}
