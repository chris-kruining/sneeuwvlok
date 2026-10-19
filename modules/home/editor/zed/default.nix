{ config, lib, pkgs, namespace, ... }: let
  inherit (lib) mkIf mkEnableOption getExe';

  cfg = config.${namespace}.editor.zed;
in {
  options.${namespace}.editor.zed = {
    enable = mkEnableOption "zed";
  };

  config = mkIf cfg.enable {
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
        "nu"
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
      ];

      userSettings = {
        assistant.enabled = false;

        vim_mode = false;
        load_direnv = "shell_hook";
        base_keymap = "JetBrains";

        format_on_save = "on";
        bindings = {
          "ctrl+s" = "workspace::SaveAll";
        };

        tabs = {
          file_icons = true;
          git_status = true;
        };
        project_panel.auto_reveal_entries = false;

        "experimental.theme_overrides" = {
          border = "#ffffff07";
        };

        hour_format = "hour24";
        auto_update = false;

        lsp = {
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

        languages = {
          "Nix" = {
            language_servers = ["nixd" "nil"];
            format_on_save = "on";
          };
        };
      };
    };
  };
}
