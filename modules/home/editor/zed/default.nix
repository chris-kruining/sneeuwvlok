{ config, lib, pkgs, namespace, ... }: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.editors.zed;
in {
  options.${namespace}.editors.zed = {
    enable = mkEnableOption "zed";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      zed-editor nixd nil alejandra
    ];

    programs.zed-editor = {
      enable = true;

      extensions = [ "nix" "toml" "html" ];

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
            binary = {
              path_lookup = true;
            };
          };
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
