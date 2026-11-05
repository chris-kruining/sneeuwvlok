{
  config,
  lib,
  pkgs,
  namespace,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf getExe concatMapStringsSep;

  osCfg = osConfig.${namespace}.desktop.hyprland or {enable = false;};

  colors = config.lib.stylix.colors;
  terminal = config.${namespace}.defaults.terminal;

  # Hyprland >= 0.56 reads hyprland.lua, see the (installed) example at
  # ${pkgs.hyprland}/share/hypr/hyprland.lua and the stubs in share/hypr/stubs
  caelestiaBinds = {
    "SUPER + Space" = "launcher";
    "SUPER + Tab" = "showall";
    "SUPER + D" = "dashboard";
    "SUPER + Escape" = "session";
    "SUPER + N" = "nexus";
    "SUPER + S" = "sidebar";
    "SUPER + U" = "utilities";
    "SUPER + L" = "lock";
    "Print" = "screenshot";
    "SHIFT + Print" = "screenshotFreeze";
    "CTRL + Print" = "screenshotClip";
  };
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
        local mainMod = "SUPER"
        local terminal = "${terminal}"
        local fileManager = "dolphin"

        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

        hl.on("hyprland.start", function()
          hl.exec_cmd("${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent")
        end)

        hl.config({
          general = {
            gaps_in = 4,
            gaps_out = 8,
            border_size = 2,
            col = {
              active_border = { colors = { "rgb(${colors.base0D})", "rgb(${colors.base0B})" }, angle = 45 },
              inactive_border = "rgb(${colors.base03})",
            },
            resize_on_border = true,
            layout = "dwindle",
          },

          decoration = {
            rounding = 8,
            shadow = { enabled = true, range = 4, render_power = 3 },
            blur = { enabled = true, size = 3, passes = 1 },
          },

          animations = { enabled = true },

          dwindle = { preserve_split = true },

          misc = {
            force_default_wallpaper = 0,
            disable_hyprland_logo = true,
          },

          input = {
            kb_layout = "us",
            follow_mouse = 1,
            touchpad = { natural_scroll = true },
          },
        })

        hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

        hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
        hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
        hl.bind(mainMod .. " + Q", hl.dsp.window.close())
        hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
        hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
        hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
        hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
        hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())

        for _, dir in ipairs({ "left", "right", "up", "down" }) do
          hl.bind(mainMod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
        end

        for i = 1, 10 do
          local key = i % 10
          hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
          hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
        end

        hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
        hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
        hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
        hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

        ${concatMapStringsSep "\n" (key: ''hl.bind("${key}", hl.dsp.global("caelestia:${caelestiaBinds.${key}}"))'') (builtins.attrNames caelestiaBinds)}

        hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
        hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
        hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
        hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
        hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
        hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
        hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
        hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
      '';
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
