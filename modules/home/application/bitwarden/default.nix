{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.bitwarden;
in
{
  options.${namespace}.application.bitwarden = {
    enable = mkEnableOption "enable bitwarden";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ bitwarden-desktop ];
  };
}
