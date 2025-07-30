{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.zen;
in
{
  options.${namespace}.application.zen = {
    enable = mkEnableOption "enable zen";
  };

  config = mkIf cfg.enable {
    home.packages = [ inputs.zen-browser.packages.${pkgs.system}.specific ];

    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };
  };
}
