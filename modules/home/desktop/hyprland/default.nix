{
  config,
  lib,
  pkgs,
  namespace,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf getExe;

  osCfg = osConfig.${namespace}.desktop.hyprland or {enable = false;};
in {
  config = mkIf osCfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;

      systemd = {
        enable = true;
        variables = ["--all"];
      };

      settings = {
        monitor = [",preferred,auto,1"];

        "$mainMod" = "SUPER";
        "$terminal" = config.${namespace}.defaults.terminal;

        exec-once = [
          (getExe pkgs.hyprpolkitagent)
        ];

        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          layout = "dwindle";
        };

        input = {
          follow_mouse = 1;
          touchpad.natural_scroll = true;
        };

        gestures.workspace_swipe = true;

        bind = [
          "$mainMod, Return, exec, $terminal"
          "$mainMod, Q, killactive"
          "$mainMod, V, togglefloating"
          "$mainMod, F, fullscreen"
          "$mainMod, J, togglesplit"

          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"

          "$mainMod, Space, global, caelestia:launcher"
          "$mainMod, Tab, global, caelestia:showall"
          "$mainMod, D, global, caelestia:dashboard"
          "$mainMod, Escape, global, caelestia:session"
          "$mainMod, N, global, caelestia:nexus"
          "$mainMod, S, global, caelestia:sidebar"
          "$mainMod, U, global, caelestia:utilities"
          ", Print, global, caelestia:screenshot"
          "SHIFT, Print, global, caelestia:screenshotFreeze"
          "$mainMod, L, global, caelestia:lock"
        ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
    };

    stylix.targets.hyprland.enable = false;

    programs.caelestia = {
      enable = true;
      cli.enable = true;

      # graphical-session.target is also reached by plasma, so the shell would start in that session as well
      systemd.target = "hyprland-session.target";
    };

    xdg.configFile."quickshell/caelestia".source = "${config.programs.caelestia.package}/share/caelestia-shell";
  };
}
