{
  config,
  lib,
  pkgs,
  namespace,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf;

  osCfg = osConfig.${namespace}.desktop.hyprland or {enable = false;};
in {
  config = mkIf osCfg.enable {
    home.packages = with pkgs; [
      brightnessctl
      playerctl
      wl-clipboard
    ];

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";

      systemd = {
        enable = true;
        variables = ["--all"];
        # runs ~/.config/autostart entries (bitwarden is the ssh agent)
        enableXdgAutostart = true;
      };

      extraConfig = ''

      '';
    };
  };
}
