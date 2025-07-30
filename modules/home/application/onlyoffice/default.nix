{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.onlyoffice;
in
{
  options.${namespace}.application.onlyoffice = {
    enable = mkEnableOption "enable onlyoffice";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ onlyoffice-bin ];
    # fonts.packages = with pkgs; [ corefonts ];
  };
}
