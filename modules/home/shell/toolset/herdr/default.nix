{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkMerge mkEnableOption getExe getExe';

  cfg = config.${namespace}.shell.toolset.herdr;

  # The agents' herdr hooks are python, run from the agent in a pane. Panes inherit the server's PATH, so it comes with herdr
  herdr = pkgs.symlinkJoin {
    name = "herdr-wrapped-${pkgs.herdr.version}";
    paths = [ pkgs.herdr ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/herdr --suffix PATH : ${lib.makeBinPath [ pkgs.python3 ]}
    '';
    inherit (pkgs.herdr) meta;
  };

  # The app writes settings.json itself too (zoom, theme), so these are merged into it rather than linked
  appSettings = pkgs.writeText "herdr-app-settings.json" (builtins.toJSON {
    telemetry = false;
  });
in
{
  options.${namespace}.shell.toolset.herdr = {
    enable = mkEnableOption "herdr, a terminal multiplexer for coding agents";

    server.enable = mkEnableOption ''
      herdr's server from boot, without logging in (the system needs `users.users.<name>.linger`).
      Its sessions keep running while other machines attach with `herdr --remote <user>@<machine>`
    '';

    app.enable = mkEnableOption ''
      herdr's desktop app. It runs on herdr-core, not on the TUI's server, so it doesn't see the TUI's sessions
    '';

    core.enable = mkEnableOption ''
      herdr-core (its CLI is hc) as a service, without the app. The app and phone of other machines show its terminals
      after `hc machine add <user>@<machine>`
    '' // { default = cfg.app.enable; };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      programs.herdr = {
        enable = true;
        package = herdr;

        settings = {
          onboarding = false;
          # Updates come with nix
          update.version_check = false;
        };
      };

      # The integrations tell herdr which conversation an agent pane is in, so it resumes them after a restart or reboot.
      # They add a hook to the agents' settings.json, which claude code and copilot both merge their declared settings into
      home.activation.herdrIntegrations = mkIf config.${namespace}.development.ai.enable (
        inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" "claudeCodeSettings" "copilotSettings" ] ''
          for agent in claude copilot; do
            if [ -d "$HOME/.$agent" ]; then
              run ${getExe herdr} integration install "$agent" >/dev/null
            fi
          done
        ''
      );

      # Stops with SIGTERM, which saves the layout and the agents to resume first
      systemd.user.services.herdr-server = mkIf cfg.server.enable {
        Unit.Description = "Herdr server";
        Service = {
          ExecStart = "${getExe herdr} server";
          Restart = "on-failure";
          # The shell new panes start, the user manager's is bash
          Environment = [ "SHELL=${getExe pkgs.${config.${namespace}.defaults.shell}}" ];
        };
        Install.WantedBy = [ "default.target" ];
      };
    })

    (mkIf cfg.core.enable {
      home.packages = [ pkgs.herdr-core ] ++ lib.optional cfg.app.enable pkgs.herdr-desktop;

      # Otherwise hc and the app start it themselves, inside whatever started them. Its terminals run in their own
      # hc-hold-* units, so restarting it (a switch) keeps them running. hc turns on linger itself when it's off
      systemd.user.services.herdr-core = {
        Unit.Description = "Herdr core";
        Service = {
          Type = "exec";
          ExecStart = "${getExe' pkgs.herdr-core "herdr-core"} serve";
          Restart = "on-failure";
          Environment = [ "SHELL=${getExe pkgs.${config.${namespace}.defaults.shell}}" ];
        };
        Install.WantedBy = [ "default.target" ];
      };
    })

    (mkIf cfg.app.enable {
      # The app applies changes to it live
      home.activation.herdrAppSettings = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        file="${config.xdg.configHome}/herdr-app/settings.json"
        run mkdir -p "$(dirname "$file")"
        if [ -e "$file" ]; then
          run ${pkgs.bash}/bin/bash -c '${getExe pkgs.jq} -s ".[0] * .[1]" "$1" ${appSettings} > "$1.new" && mv "$1.new" "$1"' _ "$file"
        else
          run install -m644 ${appSettings} "$file"
        fi
      '';
    })
  ];
}
