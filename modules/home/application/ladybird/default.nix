{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.ladybird;
in
{
  options.${namespace}.application.ladybird = {
    enable = mkEnableOption "enable ladybird";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ ladybird ];
  };
}
