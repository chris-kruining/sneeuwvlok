{ config, lib, pkgs, user, ... }: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.${user}.desktop.games;
in
{
  options.modules.${user}.desktop.games = {
    enable = mkEnableOption "enable proton GE";
  };

  config = mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = with pkgs; [ protonup ];

      home.sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
      };
    };
  };
}
