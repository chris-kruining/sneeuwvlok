{
  inputs,
  config,
  osConfig ? {},
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.${namespace}.development.ai;
  local = cfg.local;

  # My own skills, one folder each with a SKILL.md, the same format for claude code and copilot
  skills = ./skills;

  copilotSettings = pkgs.writeText "copilot-settings.json" (builtins.toJSON {
    model = "Menicon-Cloud-Services/MJ_Anthropic_API/claude-opus-5-5";
    allowedUrls = ["https://aws.amazon.com"];
  });

  penpot = inputs.self.nixosConfigurations.ulmo.config.${namespace}.services.development.penpot;
in {
  options.${namespace}.development.ai = {
    enable = mkEnableOption "AI coding assistants, claude code and copilot";

    local = {
      enable = mkEnableOption "crush, a coding agent on the local models of a llama.cpp server";

      host = mkOption {
        type = types.str;
        default = "manwe";
        description = "The machine running the llama.cpp server, its name resolves through the router at home and over the vpn";
      };

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "The port of the llama.cpp server";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      github-copilot-cli

      # For claude code's typescript lsp plugin, rust-analyzer comes with the rust module
      typescript-language-server

      # Claude code reads pasted images through `wl-paste`, copilot has its own clipboard access
      wl-clipboard
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

    programs.crush = mkIf local.enable {
      enable = true;

      # Crush has no setting for yolo, only the flag. That flag only exists on the interactive command, subcommands like `run`
      # reject it (and `run` approves everything already), so the defaults are only added when no subcommand is given
      package = let
        defaultArgs = ["--yolo"];
      in
        pkgs.symlinkJoin {
          name = "crush-wrapped-${pkgs.crush.version}";
          paths = [pkgs.crush];
          postBuild = ''
            rm $out/bin/crush
            cat > $out/bin/crush <<'EOF'
            #!${pkgs.runtimeShell}
            if [ $# -eq 0 ] || [ "''${1#-}" != "$1" ]; then
              set -- ${lib.escapeShellArgs defaultArgs} "$@"
            fi
            exec ${lib.getExe pkgs.crush} "$@"
            EOF
            chmod +x $out/bin/crush
          '';
          inherit (pkgs.crush) meta;
        };

      settings = {
        providers.llamacpp = {
          name = "llama.cpp on ${local.host}";
          type = "llamacpp";
          base_url = "http://${local.host}:${toString local.port}/v1";
          # Lists the server's models, with their context size, every time crush starts
          discover_models = true;
        };

        options = {
          # Only the local models, crush would otherwise offer and update its catalog of hosted providers
          disable_default_providers = true;
          disable_provider_auto_update = true;
          disable_metrics = true;
          # Context about a repo belongs in its README or docs, where everyone finds it
          initialize_as = "docs/agents.md";
          attribution = {
            trailer_style = "co-authored-by";
            generated_with = false;
          };
        };

        lsp.nix.command = lib.getExe pkgs.nil;

        # Penpot on ulmo. The key is in the url, crush expands `$(…)` when it loads, so it is read from the secret and
        # stays out of the store. Ulmo hands penpot the same key, see its penpot module
        mcp = lib.optionalAttrs (penpot.enable && osConfig.sops.secrets or {} ? "penpot/mcp_token") {
          penpot = {
            type = "http";
            url = "https://${penpot.domain}/mcp/stream?userToken=$(cat ${osConfig.sops.secrets."penpot/mcp_token".path})";
          };
        };
      };
    };

    # Every secret under claude/ the system declares (rules/<name>, knowledge/<project>/<name>) goes to ~/.claude as markdown.
    # Rules load in every session, knowledge is read when a rule points to it. Claude's own auto memory stays writable next to it
    home.file =
      {
        ".copilot/skills".source = skills;
      }
      // lib.mapAttrs' (name: secret: {
        name = ".claude/${lib.removePrefix "claude/" name}.md";
        value.source = config.lib.file.mkOutOfStoreSymlink secret.path;
      }) (lib.filterAttrs (name: _: lib.hasPrefix "claude/" name) (osConfig.sops.secrets or {}));

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
