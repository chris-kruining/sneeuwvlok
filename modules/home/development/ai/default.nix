{
  inputs,
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.development.ai;

  # My own skills, one folder each with a SKILL.md, the same format for claude code and copilot
  skills = ./skills;

  copilotSettings = pkgs.writeText "copilot-settings.json" (builtins.toJSON {
    model = "gpt-5.6-terra";
    allowedUrls = ["https://aws.amazon.com"];
  });
in {
  options.${namespace}.development.ai = {
    enable = mkEnableOption "AI coding assistants, claude code and copilot";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      github-copilot-cli

      # For claude code's typescript lsp plugin, rust-analyzer comes with the rust module
      typescript-language-server
    ];

    programs.claude-code = {
      enable = true;
      inherit skills;

      # Claude code writes settings.json itself as well, so the declared settings are merged into it instead of linked
      mutableSettings = true;
      settings = {
        model = "opus";
        theme = "dark";
        switchModelsOnFlag = false;
        skipDangerousModePermissionPrompt = true;

        env = {
          CLAUDE_CODE_SCROLL_SPEED = "3";
          # Updates come with nix
          DISABLE_AUTOUPDATER = "1";
        };

        enabledPlugins = {
          "rust-analyzer-lsp@claude-plugins-official" = true;
          "typescript-lsp@claude-plugins-official" = true;
          "aws-core@claude-plugins-official" = true;
        };
      };
    };

    home.file.".copilot/skills".source = skills;

    # Copilot writes settings.json itself as well (`/model`), so like claude code the declared settings win and the rest stays
    home.activation.copilotSettings = inputs.home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
      file="$HOME/.copilot/settings.json"
      run mkdir -p "$HOME/.copilot"
      if [ -e "$file" ]; then
        run ${pkgs.bash}/bin/bash -c '${lib.getExe pkgs.jq} -s ".[0] * .[1]" "$1" ${copilotSettings} > "$1.new" && mv "$1.new" "$1"' _ "$file"
      else
        run install -m644 ${copilotSettings} "$file"
      fi
    '';
  };
}
