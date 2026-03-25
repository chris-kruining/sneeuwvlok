{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.bitwarden;
in
{
  options.sneeuwvlok.application.bitwarden = {
    enable = mkEnableOption "enable bitwarden";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ bitwarden-desktop ];
  };
}
