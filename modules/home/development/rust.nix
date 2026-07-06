{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.sneeuwvlok.development.rust;
in {
  options.sneeuwvlok.development.rust = {
    enable = mkEnableOption "Enable rust development tools";
  };

  config =
    mkIf cfg.enable {
    };
}
