{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.ladybird;
in
{
  options.sneeuwvlok.application.ladybird = {
    enable = mkEnableOption "enable ladybird";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ ladybird ];
  };
}
