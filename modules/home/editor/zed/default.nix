{ config, lib, pkgs, namespace, ... }: let
  inherit (lib) mkIf mkEnableOption getExe';

  cfg = config.${namespace}.editor.zed;
in {
  options.${namespace}.editor.zed = {
    enable = mkEnableOption "zed";
  };

  config = mkIf cfg.enable {
    # The rules zed's agent follows, for commit messages
    xdg.configFile."zed/AGENTS.md".source = ./AGENTS.md;

    programs.zed-editor = {
      enable = true;

      # Rust, Go, TypeScript, JSON, CSS and YAML are built in
      extensions = [
        "nix"
        "csharp"
        "bicep"
        "terraform"
        "opentofu"
        "toml"
        "tombi"
        "html"
        "xml"
        "marksman"
        "dockerfile"
        "docker-compose"
        "github-actions"
        "just"
        "just-ls"
        "sql"
        "ini"
        "log"
      ];

      # Language servers from nixpkgs, zed looks for them in PATH before downloading its own (which don't run on nixos).
      # html and github-actions install theirs with npm, on this node
      extraPackages = with pkgs; [
        nixd
        nil
        alejandra
        rust-analyzer
        gopls
        vtsls
        nodejs
        vscode-langservers-extracted
        yaml-language-server
        roslyn-ls
        bicep-lsp
        terraform-ls
        tofu-ls
        tombi
        lemminx
        marksman
        dockerfile-language-server
        docker-language-server
        just-lsp
        omnisharp-roslyn
      ];

      # Zed changes its settings and keymap itself as well, these are merged in on every switch
      userSettings = {
        vim_mode = false;
        load_direnv = "shell_hook";
        base_keymap = "JetBrains";

        format_on_save = "on";
        ensure_final_newline_on_save = true;
        use_autoclose = true;
        soft_wrap = "prefer_line";
        search_wrap = true;
        completions.lsp_insert_mode = "replace";
        gutter.line_numbers = true;
        status_bar.line_endings_button = true;
        file_finder.skip_focus_for_active_in_search = true;

        tabs = {
          file_icons = true;
          git_status = true;
        };

        project_panel = {
          dock = "left";
          hide_hidden = false;
          hide_root = false;
          starts_open = false;
          auto_reveal_entries = false;
          bold_folder_labels = false;
          default_width = 240;
          entry_spacing = "standard";
          indent_guides.show = "always";
          scrollbar.show = "auto";
        };
        outline_panel = {
          dock = "left";
          folder_icons = true;
          file_icons = true;
        };
        git_panel = {
          dock = "left";
          status_style = "icon";
        };
        collaboration_panel.dock = "left";

        agent = {
          dock = "right";
          sidebar_side = "right";
          default_profile = "write";
          tool_permissions.default = "allow";
          default_model = {
            provider = "copilot_chat";
            model = "claude-sonnet 5";
          };
          commit_message_instructions = "Use the Conventional Commits format: <type>(<scope>): <description>.";
        };

        file_types.XML = ["slnx" "csproj"];

        "experimental.theme_overrides" = {
          border = "#ffffff07";
        };

        hour_format = "hour24";
        auto_update = false;

        lsp = {
          vtsls = {
            enable_lsp_tasks = true;
            settings = {
              typescript.updateImportsOnFileMove.enabled = "always";
              javascript.updateImportsOnFileMove.enabled = "always";
            };
          };

          nixd = {};
          nil = {
            initialization_options = {
              nix = {
                flake = {
                  autoArchive = true;
                };
              };
              formatting = {
                command = ["alejandra" "--quiet" "--"];
              };
            };
          };

          # These extensions never look in PATH, and with a path set the csharp one no longer adds its arguments
          roslyn.binary = {
            path = getExe' pkgs.roslyn-ls "Microsoft.CodeAnalysis.LanguageServer";
            arguments = ["--stdio" "--autoLoadProjects"];
          };
          bicep-ls.binary.path = getExe' pkgs.bicep-lsp "Bicep.LangServer";
        };

        languages = let
          # typescript-language-server before vtsls
          typescript.language_servers = ["typescript-language-server" "!vtsls" "..."];
        in {
          "Nix" = {
            language_servers = ["nixd" "nil"];
            format_on_save = "on";
          };
          "Markdown".format_on_save = "off";
          "CSharp".language_servers = ["omnisharp" "roslyn"];
          "TypeScript" = typescript;
          "TSX" = typescript;
          "JavaScript" = typescript;
        };
      };

      userKeymaps = [
        {
          context = "Workspace";
          bindings = {
            "ctrl-s" = "workspace::SaveAll";
            "ctrl-r" = null;
          };
        }
        {
          context = "Editor";
          bindings = {
            "f2" = "editor::Rename";
            "ctrl-;" = null;
          };
        }
      ];
    };
  };
}
