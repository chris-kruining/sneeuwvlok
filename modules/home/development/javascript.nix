{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.sneeuwvlok.development.javascript;
in {
  options.sneeuwvlok.development.javascript = {
    enable = mkEnableOption "Enable javascript development tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [bun nodejs typescript-language-server];
  };
}
