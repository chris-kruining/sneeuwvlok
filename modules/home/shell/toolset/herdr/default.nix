{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption getExe;

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
in
{
  options.${namespace}.shell.toolset.herdr = {
    enable = mkEnableOption "herdr, a terminal multiplexer for coding agents";

    server.enable = mkEnableOption ''
      herdr's server from boot, without logging in (the system needs `users.users.<name>.linger`).
      Its sessions keep running while other machines attach with `herdr --remote <user>@<machine>`
    '';
  };

  config = mkIf cfg.enable {
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
  };
}
