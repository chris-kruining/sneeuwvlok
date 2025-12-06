{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.steam;
in
{
  options.${namespace}.application.steam = {
    enable = mkEnableOption "enable steam";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ protonup-ng ];

    home.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
    };

    programs = {
      # steam = {
      #   enable = true;
      #   package = pkgs.steam-small.override {
      #     extraEnv = {
      #       DXVK_HUD = "compiler";
      #       MANGOHUD = true;
      #     };
      #   };

      #   gamescopeSession = {
      #     enable = true;
      #     args = ["--immediate-flips"];
      #   };
      # };

      # https://github.com/FeralInteractive/gamemode
      # gamemode = {
      #   enable = true;
      #   enableRenice = true;
      #   settings = {};
      # };

      # gamescope = {
      #   enable = true;
      #   capSysNice = true;
      #   env = {
      #     DXVK_HDR = "1";
      #     ENABLE_GAMESCOPE_WSI = "1";
      #     WINE_FULLSCREEN_FSR = "1";
      #     WLR_RENDERER = "vulkan";
      #   };
      #   args = ["--hdr-enabled"];
      # };
    };
  };
}
